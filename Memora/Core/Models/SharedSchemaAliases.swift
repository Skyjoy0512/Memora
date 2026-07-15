import MemoraSharedSchema

// The SwiftData definitions live in MemoraSharedSchema so that the iOS host and
// future React Native host use exactly the same persistent model identities.
// Keep these aliases in the app target to make this a location-only move for
// existing SwiftUI, service, and test code.
typealias AskAIMessageRole = MemoraSharedSchema.AskAIMessageRole
typealias AskAIMessage = MemoraSharedSchema.AskAIMessage
typealias AskAIScopeType = MemoraSharedSchema.AskAIScopeType
typealias AskAISession = MemoraSharedSchema.AskAISession
typealias AudioFile = MemoraSharedSchema.AudioFile
typealias AudioFileRepositoryProtocol = MemoraSharedSchema.AudioFileRepositoryProtocol
typealias AudioFileRepository = MemoraSharedSchema.AudioFileRepository
typealias BotMeetingConfig = MemoraSharedSchema.BotMeetingConfig
typealias CalendarEventLink = MemoraSharedSchema.CalendarEventLink
typealias CustomSummaryTemplate = MemoraSharedSchema.CustomSummaryTemplate
typealias GoogleMeetSettings = MemoraSharedSchema.GoogleMeetSettings
typealias KnowledgeChunkScopeType = MemoraSharedSchema.KnowledgeChunkScopeType
typealias KnowledgeChunkSourceType = MemoraSharedSchema.KnowledgeChunkSourceType
typealias KnowledgeChunk = MemoraSharedSchema.KnowledgeChunk
typealias MeetingMemo = MemoraSharedSchema.MeetingMemo
typealias MeetingNote = MemoraSharedSchema.MeetingNote
typealias MemoraSchemaV1 = MemoraSharedSchema.MemoraSchemaV1
typealias MemoraSchemaV2 = MemoraSharedSchema.MemoraSchemaV2
typealias MemoraSchemaV3 = MemoraSharedSchema.MemoraSchemaV3
typealias MemoraMigrationPlan = MemoraSharedSchema.MemoraMigrationPlan
typealias MemoryFact = MemoraSharedSchema.MemoryFact
typealias MemoryProfile = MemoraSharedSchema.MemoryProfile
typealias NotionSettings = MemoraSharedSchema.NotionSettings
typealias OnlineMeetingCapture = MemoraSharedSchema.OnlineMeetingCapture
typealias PhotoAttachmentOwnerType = MemoraSharedSchema.PhotoAttachmentOwnerType
typealias PhotoAttachment = MemoraSharedSchema.PhotoAttachment
typealias PlaudSettings = MemoraSharedSchema.PlaudSettings
typealias ProcessingJob = MemoraSharedSchema.ProcessingJob
typealias Project = MemoraSharedSchema.Project
typealias ScheduledBotMeeting = MemoraSharedSchema.ScheduledBotMeeting
typealias SourceType = MemoraSharedSchema.SourceType
typealias TodoItem = MemoraSharedSchema.TodoItem
typealias Transcript = MemoraSharedSchema.Transcript
typealias TranscriptionCheckpoint = MemoraSharedSchema.TranscriptionCheckpoint
typealias WebhookEventType = MemoraSharedSchema.WebhookEventType
typealias WebhookSettings = MemoraSharedSchema.WebhookSettings
