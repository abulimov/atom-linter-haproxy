{BufferedProcess, CompositeDisposable} = require 'atom'
helpers = require 'atom-linter'

module.exports =
  config:
    executablePath:
      type: 'string'
      title: 'haproxy-linter Executable Path'
      default: 'haproxy-lint'
  activate: ->
    require('atom-package-deps').install('linter-haproxy')
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'linter-haproxy.executablePath',
      (executablePath) =>
        @executablePath = executablePath
  deactivate: ->
    @subscriptions.dispose()
  provideLinter: ->
    provider =
      grammarScopes: ['source.haproxy-config', 'haproxy.cfg']
      scope: 'file' # or 'project'
      lintOnFly: false # must be false for scope: 'project'
      lint: (textEditor) =>
        return new Promise (resolve, reject) =>
          filePath = textEditor.getPath()
          project_path = atom.project.getPaths()

          linter_result = ""
          linter_args = ["--json"]
          linter_args.push filePath

          error_stack = []
          process = new BufferedProcess
            command: @executablePath
            args: linter_args
            options:
              cwd: project_path[0]
            stdout: (data) ->
              linter_result += data
            exit: (code) ->
              try
                parsed = JSON.parse(linter_result)
              catch error
                atom.notifications.addError "Failed to parse output from haproxy-lint",
                  detail: "#{error.message}"
                  dismissable: true
              for error in parsed
                console.log "#{error.line}"
                error_stack.push
                  type: if error.severity == "warning" then "Warning" else "Error"
                  text: error.message
                  filePath: filePath
                  range: helpers.rangeFromLineNumber(textEditor, error.line - 1)
              resolve error_stack
          process.onWillThrowError ({error,handle}) ->
            atom.notifications.addError "Failed to run #{@executablePath}",
              detail: "#{error.message}"
              dismissable: true
            handle()
            resolve []
