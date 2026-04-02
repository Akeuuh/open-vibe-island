import Foundation

public enum MockAgentScenario {
    public static let initialEvents: [AgentEvent] = {
        let base = Date.now.addingTimeInterval(-300)

        return [
            .sessionStarted(
                SessionStarted(
                    sessionID: "claude-fix-auth-bug",
                    title: "fix auth bug",
                    tool: .claudeCode,
                    summary: "Inspecting auth middleware and reproducing the failure.",
                    timestamp: base,
                    jumpTarget: JumpTarget(
                        terminalApp: "iTerm",
                        workspaceName: "backend",
                        paneTitle: "auth bug"
                    )
                )
            ),
            .sessionStarted(
                SessionStarted(
                    sessionID: "codex-backend-server",
                    title: "backend server",
                    tool: .codex,
                    summary: "Building REST endpoints and wiring tests.",
                    timestamp: base.addingTimeInterval(-90),
                    jumpTarget: JumpTarget(
                        terminalApp: "Terminal",
                        workspaceName: "api",
                        paneTitle: "backend server"
                    )
                )
            ),
            .sessionStarted(
                SessionStarted(
                    sessionID: "gemini-optimize-queries",
                    title: "optimize queries",
                    tool: .geminiCLI,
                    summary: "Profiling slow queries in the read path.",
                    timestamp: base.addingTimeInterval(-180),
                    jumpTarget: JumpTarget(
                        terminalApp: "Ghostty",
                        workspaceName: "db",
                        paneTitle: "optimize queries"
                    )
                )
            ),
        ]
    }()

    public static func timeline(referenceDate: Date = .now) -> [ScheduledAgentEvent] {
        [
            ScheduledAgentEvent(
                delay: 1.5,
                event: .activityUpdated(
                    SessionActivityUpdated(
                        sessionID: "claude-fix-auth-bug",
                        summary: "Reading `middleware.ts` and checking token expiry handling.",
                        phase: .running,
                        timestamp: referenceDate.addingTimeInterval(1.5)
                    )
                )
            ),
            ScheduledAgentEvent(
                delay: 4,
                event: .permissionRequested(
                    PermissionRequested(
                        sessionID: "claude-fix-auth-bug",
                        request: PermissionRequest(
                            title: "Edit auth middleware",
                            summary: "Claude wants to edit `src/auth/middleware.ts` to guard missing tokens.",
                            affectedPath: "src/auth/middleware.ts"
                        ),
                        timestamp: referenceDate.addingTimeInterval(4)
                    )
                )
            ),
            ScheduledAgentEvent(
                delay: 7,
                event: .questionAsked(
                    QuestionAsked(
                        sessionID: "gemini-optimize-queries",
                        prompt: QuestionPrompt(
                            title: "Which deployment target should the query changes optimize for?",
                            options: ["Production", "Staging", "Local only"]
                        ),
                        timestamp: referenceDate.addingTimeInterval(7)
                    )
                )
            ),
            ScheduledAgentEvent(
                delay: 10,
                event: .activityUpdated(
                    SessionActivityUpdated(
                        sessionID: "codex-backend-server",
                        summary: "Running `npm test` after writing `users.ts`.",
                        phase: .running,
                        timestamp: referenceDate.addingTimeInterval(10)
                    )
                )
            ),
            ScheduledAgentEvent(
                delay: 14,
                event: .sessionCompleted(
                    SessionCompleted(
                        sessionID: "codex-backend-server",
                        summary: "REST endpoints built. Tests are green.",
                        timestamp: referenceDate.addingTimeInterval(14)
                    )
                )
            ),
        ]
    }
}
