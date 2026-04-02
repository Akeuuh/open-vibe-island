import Foundation

public enum AgentTool: String, CaseIterable, Codable, Sendable {
    case claudeCode
    case codex
    case geminiCLI

    public var displayName: String {
        switch self {
        case .claudeCode:
            "Claude Code"
        case .codex:
            "Codex"
        case .geminiCLI:
            "Gemini CLI"
        }
    }

    public var shortName: String {
        switch self {
        case .claudeCode:
            "CLAUDE"
        case .codex:
            "CODEX"
        case .geminiCLI:
            "GEMINI"
        }
    }
}

public enum SessionPhase: String, Codable, Sendable {
    case running
    case waitingForApproval
    case waitingForAnswer
    case completed

    public var displayName: String {
        switch self {
        case .running:
            "Running"
        case .waitingForApproval:
            "Needs approval"
        case .waitingForAnswer:
            "Needs answer"
        case .completed:
            "Completed"
        }
    }

    public var requiresAttention: Bool {
        switch self {
        case .waitingForApproval, .waitingForAnswer:
            true
        case .running, .completed:
            false
        }
    }
}

public struct JumpTarget: Equatable, Codable, Sendable {
    public var terminalApp: String
    public var workspaceName: String
    public var paneTitle: String

    public init(terminalApp: String, workspaceName: String, paneTitle: String) {
        self.terminalApp = terminalApp
        self.workspaceName = workspaceName
        self.paneTitle = paneTitle
    }
}

public struct PermissionRequest: Equatable, Identifiable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var affectedPath: String
    public var primaryActionTitle: String
    public var secondaryActionTitle: String

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        affectedPath: String,
        primaryActionTitle: String = "Allow",
        secondaryActionTitle: String = "Deny"
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.affectedPath = affectedPath
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
    }
}

public struct QuestionPrompt: Equatable, Identifiable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var options: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        options: [String]
    ) {
        self.id = id
        self.title = title
        self.options = options
    }
}

public struct AgentSession: Equatable, Identifiable, Codable, Sendable {
    public var id: String
    public var title: String
    public var tool: AgentTool
    public var phase: SessionPhase
    public var summary: String
    public var updatedAt: Date
    public var permissionRequest: PermissionRequest?
    public var questionPrompt: QuestionPrompt?
    public var jumpTarget: JumpTarget?

    public init(
        id: String,
        title: String,
        tool: AgentTool,
        phase: SessionPhase,
        summary: String,
        updatedAt: Date,
        permissionRequest: PermissionRequest? = nil,
        questionPrompt: QuestionPrompt? = nil,
        jumpTarget: JumpTarget? = nil
    ) {
        self.id = id
        self.title = title
        self.tool = tool
        self.phase = phase
        self.summary = summary
        self.updatedAt = updatedAt
        self.permissionRequest = permissionRequest
        self.questionPrompt = questionPrompt
        self.jumpTarget = jumpTarget
    }
}
