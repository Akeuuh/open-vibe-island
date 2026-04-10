// Tests/OpenIslandCoreTests/GeminiHookTests.swift
import Testing
import Foundation
@testable import OpenIslandCore

@Suite("GeminiHooks")
struct GeminiHookTests {
    @Test func decodesSessionStartPayload() throws {
        let json = """
        {
          "session_id": "abc-123",
          "hook_event_name": "SessionStart",
          "cwd": "/Users/user/project",
          "model": "gemini-2.0-flash"
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(GeminiHookPayload.self, from: json)
        #expect(payload.sessionID == "abc-123")
        #expect(payload.hookEventName == .sessionStart)
        #expect(payload.model == "gemini-2.0-flash")
        #expect(payload.cwd == "/Users/user/project")
    }

    @Test func decodesPreToolUsePayload() throws {
        let json = """
        {
          "session_id": "xyz",
          "hook_event_name": "PreToolUse",
          "cwd": "/tmp",
          "model": "gemini-2.0-flash",
          "tool_name": "bash",
          "tool_input": {"command": "ls -la"}
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(GeminiHookPayload.self, from: json)
        #expect(payload.hookEventName == .preToolUse)
        #expect(payload.toolName == "bash")
        #expect(payload.toolInput?.command == "ls -la")
    }

    @Test func encoderReturnsNilForAcknowledged() {
        let result = GeminiHookOutputEncoder.standardOutput(for: .acknowledged)
        #expect(result == nil)
    }

    @Test func optionalFieldsDecodeAsNilWhenAbsent() throws {
        let json = """
        {
          "session_id": "s1",
          "hook_event_name": "Stop",
          "cwd": "/tmp",
          "model": "gemini-2.0-flash"
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(GeminiHookPayload.self, from: json)
        #expect(payload.toolName == nil)
        #expect(payload.toolInput == nil)
        #expect(payload.lastAssistantMessage == nil)
    }

    @Test func implicitStartSummaryForAllEvents() {
        let base = GeminiHookPayload(sessionID: "s", hookEventName: .sessionStart, cwd: "/Users/user/myapp", model: "g")
        var p = base
        p = GeminiHookPayload(sessionID: "s", hookEventName: .sessionStart, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("Started"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .preToolUse, cwd: "/Users/user/myapp", model: "g", toolName: "bash")
        #expect(p.implicitStartSummary.contains("bash"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .postToolUse, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("finished"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .stop, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("completed"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .userPromptSubmit, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("prompt"))
    }

    @Test func installerAddsManagedHooksToEmptyFile() throws {
        let mutation = try GeminiHookInstaller.installSettingsJSON(
            existingData: nil,
            hookCommand: "/usr/local/bin/open-island-hooks --source gemini"
        )
        #expect(mutation.changed == true)
        #expect(mutation.managedHooksPresent == true)
        let obj = try JSONSerialization.jsonObject(with: mutation.contents!) as! [String: Any]
        let hooks = obj["hooks"] as! [String: Any]
        let entries = hooks["PreToolUse"] as! [[String: String]]
        #expect(entries.first?["command"]?.contains("--source gemini") == true)
    }

    @Test func installerUninstallRemovesManagedHooks() throws {
        let installed = try GeminiHookInstaller.installSettingsJSON(
            existingData: nil,
            hookCommand: "/usr/local/bin/open-island-hooks --source gemini"
        )
        let uninstalled = try GeminiHookInstaller.uninstallSettingsJSON(
            existingData: installed.contents,
            hookCommand: "/usr/local/bin/open-island-hooks --source gemini"
        )
        #expect(uninstalled.changed == true)
        #expect(uninstalled.managedHooksPresent == false)
    }

    @Test func installerPreservesExistingUserHooks() throws {
        let existing = """
        {"hooks":{"PreToolUse":[{"command":"echo user-hook"}]}}
        """.data(using: .utf8)!
        let mutation = try GeminiHookInstaller.installSettingsJSON(
            existingData: existing,
            hookCommand: "/usr/local/bin/open-island-hooks --source gemini"
        )
        let obj = try JSONSerialization.jsonObject(with: mutation.contents!) as! [String: Any]
        let hooks = obj["hooks"] as! [String: Any]
        let entries = hooks["PreToolUse"] as! [[String: String]]
        #expect(entries.count == 2)
    }

    @Test func installationManagerReturnsGeminiNotFoundForMissingDirectory() throws {
        let tempURL = URL(fileURLWithPath: "/tmp/gemini-test-nonexistent-\(UUID().uuidString)")
        let manager = GeminiHookInstallationManager(geminiDirectory: tempURL)
        let status = try manager.status(
            hooksBinaryURL: URL(fileURLWithPath: "/usr/local/bin/open-island-hooks")
        )
        #expect(status == .geminiNotFound)
    }
}
