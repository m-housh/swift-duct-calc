import AuthClient
import DatabaseClient
import Foundation
import ManualDCore
import Vapor

struct MetricFeatureKey: StorageKey {
  typealias Value = MetricFeature
}

struct MetricsRecorderKey: StorageKey {
  typealias Value = AggregateMetricsRecorder
}

/// This actor receives only enum labels, counts, and durations. No request or user objects.
actor AggregateMetricsRecorder {
  private var buckets: [MetricBucket: MetricCount] = [:]
  private var task: Task<Void, Never>?
  private var flushing = false
  private let database: DatabaseClient.AdminMetrics
  private let logger: Logger
  private let enabled: Bool

  init(database: DatabaseClient.AdminMetrics, logger: Logger, enabled: Bool = true) {
    self.database = database
    self.logger = logger
    self.enabled = enabled
  }

  func record(
    feature: MetricFeature, status: Int, milliseconds: Double, signup: Bool, now: Date = Date()
  ) {
    guard enabled else { return }
    let day = MetricCalendar.day(now)
    // A database outage cannot grow this buffer: flushes discard failed batches. Bound dates
    // as well in case the clock changes before the next flush.
    if buckets.count >= 512 { return }
    let bucket = MetricBucket(day: day, feature: feature, statusClass: min(5, max(1, status / 100)))
    buckets[bucket, default: .init()].count += 1
    buckets[bucket, default: .init()].durationMilliseconds += max(0, milliseconds)
    if signup {
      let signups = MetricBucket(day: day, feature: .signups, statusClass: 0)
      buckets[signups, default: .init()].count += 1
    }
  }

  func flush(now: Date = Date()) async {
    guard !flushing else { return }
    flushing = true
    defer { flushing = false }
    var batch = buckets
    buckets.removeAll(keepingCapacity: true)
    batch[.init(day: MetricCalendar.day(now), feature: .coverage, statusClass: 0)] = .init()
    do {
      if enabled {
        try await database.flush(batch, now)
      } else {
        try await database.prune(now)
      }
    } catch {
      // No error interpolation: database errors may contain bound values. Do not retry an
      // uncertain commit, which could double count. These are best-effort usage metrics.
      logger.warning("Aggregate metrics flush failed; this interval may be incomplete")
    }
  }

  func start() async {
    guard task == nil else { return }
    await flush()
    task = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(60)) } catch { return }
        guard !Task.isCancelled else { return }
        await self?.flush()
      }
    }
  }

  func stop() async {
    guard let running = task else { return }
    running.cancel()
    await running.value
    self.task = nil
    await flush()
  }
}

struct AggregateMetricsLifecycle: LifecycleHandler {
  let recorder: AggregateMetricsRecorder
  func didBootAsync(_ application: Application) async throws { await recorder.start() }
  func shutdownAsync(_ application: Application) async { await recorder.stop() }
}

struct AggregateMetricsMiddleware: AsyncMiddleware {
  let recorder: AggregateMetricsRecorder

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    let start = ContinuousClock.now
    do {
      let response = try await next.respond(to: request)
      await record(request, status: Int(response.status.code), start: start)
      return response
    } catch {
      await record(
        request, status: Int((error as? any AbortError)?.status.code ?? 500), start: start)
      throw error
    }
  }

  private func record(_ request: Request, status: Int, start: ContinuousClock.Instant) async {
    guard let feature = request.storage[MetricFeatureKey.self] else { return }
    let elapsed = start.duration(to: .now).components
    await recorder.record(
      feature: feature, status: status,
      milliseconds: Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15,
      signup: request.storage[SignupMetricKey.self] == true)
  }
}

extension SiteRoute {
  var metricFeature: MetricFeature? {
    switch self {
    case .health: return nil
    case .view(let view):
      switch view {
      case .test: return nil
      case .home, .privacyPolicy: return .home
      case .login, .signup: return .accounts
      case .user(.templates): return .templates
      case .user: return .accounts
      case .project: return .projects
      case .ductulator: return .ductulator
      case .fittings, .fittingReference: return .fittings
      }
    }
  }
}
