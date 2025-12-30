import Elementary
import ElementaryHTMX
import ManualDCore

struct ProjectForm: HTML, Sendable {

  let project: Project?

  init(
    project: Project? = nil
  ) {
    self.project = project
  }

  var body: some HTML {
    // TODO: Add htmx attributes.
    div(.class("mx-20 my-20")) {
      form(.class("w-full max-w-sm")) {
        div(.class("flex items-center mb-6")) {
          label(
            .for("name"), .class("block text-gray-500 font-bold mr-4")
          ) { "Name:" }
          input(
            .type(.text), .name("name"), .placeholder("Customer Name"),
            .value(project?.name ?? ""), .required, .autofocus
          )
          .defaultInput()
        }
        div(.class("flex items-center mb-6")) {
          label(.for("streetAddress"), .class("block text-gray-500 font-bold mr-4")) { "Address:" }
          input(
            .type(.text), .name("streetAddress"),
            .placeholder("Street Address"),
            .value(project?.streetAddress ?? ""),
            .required
          )
          .defaultInput()
        }
        // div(.class("w-full space-x-2")) {
        //   label(.for("city")) { "City:" }
        //
        //   input(
        //     .type(.text), .name("city"),
        //     .placeholder("City"),
        //     .value(project?.city ?? ""),
        //     .required
        //   )
        //   .defaultInput()
        // }
        // div(.class("w-full space-y-2")) {
        //   label(.for("state")) { "State:" }
        //   input(
        //     .type(.text), .name("state"),
        //     .placeholder("State"),
        //     .value(project?.state ?? ""),
        //     .required
        //   )
        //   .defaultInput()
        // }
        // div(.class("w-full space-y-2")) {
        //   label(.for("zipCode")) {
        //     "Zip:"
        //   }
        //   input(
        //     .type(.text), .name("zipCode"),
        //     .placeholder("Zip Code"),
        //     .value(project?.zipCode ?? ""),
        //     .required
        //   )
        //   .defaultInput()
        // }
      }
    }
  }
}

// TODO: Move
extension input {
  func defaultInput() -> some HTML<HTMLTag.input> {
    attributes(
      .class(
        "w-full rounded-md bg-white px-3 py-1.5 text-slate-900 outline-1 -outline-offset-1 outline-slate-300 focus:outline focus:-outline-offset-2 focus:outline-indigo-600"
      )
    )
  }
}
