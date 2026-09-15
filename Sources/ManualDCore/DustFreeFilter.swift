extension AirFilter {
  // Static Pressure vs Flow Rate summary tables, page 3 of the Sixteen manual, Rev. 1A 05/24.
  // Use the published two-decimal summary values; the embedded lab reports differ in precision.
  // https://trutechtools.com/content/brands/dustfree/documents/dustfree16-manual.pdf
  static let dustFree: [Self] = [
    .init(
      id: "dust-free-08611", manufacturer: "Dust Free", model: "Sixteen 3-ton",
      description: "MERV 16",
      points: [
        .init(airflow: 300, pressureDrop: 0.02),
        .init(airflow: 600, pressureDrop: 0.04),
        .init(airflow: 900, pressureDrop: 0.08),
        .init(airflow: 1200, pressureDrop: 0.13),
        .init(airflow: 1350, pressureDrop: 0.15),
        .init(airflow: 1500, pressureDrop: 0.18),
      ], source: "dust-free-08611"),
    .init(
      id: "dust-free-08610", manufacturer: "Dust Free", model: "Sixteen 5-ton",
      description: "MERV 16",
      points: [
        .init(airflow: 400, pressureDrop: 0.02),
        .init(airflow: 800, pressureDrop: 0.05),
        .init(airflow: 1200, pressureDrop: 0.09),
        .init(airflow: 1600, pressureDrop: 0.13),
        .init(airflow: 2000, pressureDrop: 0.18),
        .init(airflow: 2200, pressureDrop: 0.22),
      ], source: "dust-free-08610"),
  ]
}
