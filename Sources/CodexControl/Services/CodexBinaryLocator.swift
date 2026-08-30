import Foundation

enum CodexBinaryLocator {
    static func resolve() -> String? {
        for candidate in self.pathCandidates() where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return self.resolveFromLoginShell()
    }

    static func resolvedEnvironment(codexHome: String? = nil, binaryPath: String? = nil) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let codexHome {
            env["CODEX_HOME"] = codexHome
        }
        env["PATH"] = self.resolvedPathEnvironment(binaryPath: binaryPath)
        return env
    }

    static func resolvedPathEnvironment(binaryPath: String? = nil) -> String {
        var candidateDirectories: [String] = []

        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // 1. Scan NVM node versions (prioritize active/installed node versions)
        let nvmNodeDir = URL(fileURLWithPath: "\(home)/.nvm/versions/node")
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmNodeDir.path) {
            let sortedVersions = versions.sorted { $0.localizedStandardCompare($1) == .orderedDescending }
            for version in sortedVersions {
                candidateDirectories.append(nvmNodeDir.appendingPathComponent(version).appendingPathComponent("bin").path)
            }
        }

        // 2. Scan FNM / ASDF / Proto / Volta / Bun
        candidateDirectories.append(contentsOf: [
            "\(home)/.fnm/current/bin",
            "\(home)/.local/share/fnm/current/bin",
            "\(home)/.asdf/shims",
            "\(home)/.asdf/bin",
            "\(home)/.proto/shims",
            "\(home)/.proto/bin",
            "\(home)/.volta/bin",
            "\(home)/.bun/bin",
            "\(home)/.npm-global/bin",
        ])

        // 3. Scan asdf node versions
        let asdfNodeDir = URL(fileURLWithPath: "\(home)/.asdf/installs/nodejs")
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: asdfNodeDir.path) {
            let sortedVersions = versions.sorted { $0.localizedStandardCompare($1) == .orderedDescending }
            for version in sortedVersions {
                candidateDirectories.append(asdfNodeDir.appendingPathComponent(version).appendingPathComponent("bin").path)
            }
        }

        // 4. Resolve full PATH from user's login shell
        if let loginPath = self.resolveLoginShellPath() {
            candidateDirectories.append(contentsOf: loginPath.split(separator: ":").map(String.init))
        }

        // 5. Binary containing folder
        if let binaryPath, !binaryPath.isEmpty {
            let binaryDir = URL(fileURLWithPath: binaryPath).deletingLastPathComponent().path
            candidateDirectories.append(binaryDir)
        }

        // 6. Current process PATH
        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            candidateDirectories.append(contentsOf: envPath.split(separator: ":").map(String.init))
        }

        // 7. Common tool and package manager paths
        candidateDirectories.append(contentsOf: [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.cargo/bin",
            "\(home)/.local/bin",
        ])

        // 8. Base system fallback paths
        candidateDirectories.append(contentsOf: [
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ])

        var seen = Set<String>()
        var validDirs: [String] = []

        for dir in candidateDirectories {
            let trimmed = dir.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = URL(fileURLWithPath: trimmed).standardized.path
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: normalized, isDirectory: &isDir), isDir.boolValue {
                validDirs.append(normalized)
            }
        }

        // Prioritize directories that have a verified working `node` executable
        var workingNodeDirs: [String] = []
        var otherDirs: [String] = []

        for dir in validDirs {
            if self.isWorkingNode(at: dir) {
                workingNodeDirs.append(dir)
            } else {
                otherDirs.append(dir)
            }
        }

        return (workingNodeDirs + otherDirs).joined(separator: ":")
    }

    private static func isWorkingNode(at directory: String) -> Bool {
        let nodePath = URL(fileURLWithPath: directory).appendingPathComponent("node", isDirectory: false).path
        guard FileManager.default.isExecutableFile(atPath: nodePath) else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = ["-v"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func pathCandidates() -> [String] {
        var candidates: [String] = []
        let pathEnv = self.resolvedPathEnvironment()

        for component in pathEnv.split(separator: ":").map(String.init) where !component.isEmpty {
            candidates.append(URL(fileURLWithPath: component).appendingPathComponent("codex", isDirectory: false).path)
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.npm-global/bin/codex",
        ])

        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private static func resolveLoginShellPath() -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "printf \"%s\" \"$PATH\""]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0,
              let data = try? output.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            return nil
        }

        return text
    }

    private static func resolveFromLoginShell() -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v codex"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0,
              let data = try? output.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            return nil
        }

        return text
    }
}
