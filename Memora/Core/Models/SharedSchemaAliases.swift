import MemoraSharedSchema
import MemoraSharedCore

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

// Core contracts live in MemoraSharedCore so native hosts can share the STT/AI
// boundary without bringing SwiftData or host capabilities into the target.
typealias AudioError = MemoraSharedCore.AudioError
typealias ChatMessage = MemoraSharedCore.ChatMessage
typealias ChatRole = MemoraSharedCore.ChatRole
typealias ChatScope = MemoraSharedCore.ChatScope
typealias CoreError = MemoraSharedCore.CoreError
typealias DependencyPermissionMatrix = MemoraSharedCore.DependencyPermissionMatrix
typealias LLMError = MemoraSharedCore.LLMError
typealias LLMProvider = MemoraSharedCore.LLMProvider
typealias LLMProviderError = MemoraSharedCore.LLMProviderError
typealias LLMProviderKind = MemoraSharedCore.LLMProviderKind
typealias LLMProviderSummary = MemoraSharedCore.LLMProviderSummary
typealias MeetingNoteTemplate = MemoraSharedCore.MeetingNoteTemplate
typealias PipelineError = MemoraSharedCore.PipelineError
typealias PipelineEvent = MemoraSharedCore.PipelineEvent
typealias PipelineStep = MemoraSharedCore.PipelineStep
typealias RelativeDueDate = MemoraSharedCore.RelativeDueDate
typealias STTEvent = MemoraSharedCore.STTEvent
typealias STTReadinessProtocol = MemoraSharedCore.STTReadinessProtocol
typealias STTServiceProtocol = MemoraSharedCore.STTServiceProtocol
typealias STTTaskHandleProtocol = MemoraSharedCore.STTTaskHandleProtocol
typealias SummarizationResult = MemoraSharedCore.SummarizationResult
typealias SummaryError = MemoraSharedCore.SummaryError
typealias TodoExtractionResult = MemoraSharedCore.TodoExtractionResult
typealias TodoPriority = MemoraSharedCore.TodoPriority
typealias TranscriptionError = MemoraSharedCore.TranscriptionError
typealias TranscriptionResult = MemoraSharedCore.TranscriptionResult
typealias TranscriptionSegment = MemoraSharedCore.TranscriptionSegment

// STT execution helpers live in MemoraSharedCore. Keep app-side aliases so
// existing service and test imports remain a location-only migration.
typealias AudioChunk = MemoraSharedCore.AudioChunk
typealias AudioChunker = MemoraSharedCore.AudioChunker
typealias AudioChunkerError = MemoraSharedCore.AudioChunkerError
typealias AudioChunkerProtocol = MemoraSharedCore.AudioChunkerProtocol
typealias AudioChunkPlan = MemoraSharedCore.AudioChunkPlan
typealias AudioChunkProgressHandler = MemoraSharedCore.AudioChunkProgressHandler
typealias STTFileLocations = MemoraSharedCore.STTFileLocations
typealias LocalSTTBackendFactory = MemoraSharedCore.LocalSTTBackendFactory
typealias RemoteTranscribing = MemoraSharedCore.RemoteTranscribing
typealias RemoteTranscriptionRequest = MemoraSharedCore.RemoteTranscriptionRequest
typealias SpeechAnalyzerTranscribing = MemoraSharedCore.SpeechAnalyzerTranscribing
typealias SpeakerDiarizationProtocol = MemoraSharedCore.SpeakerDiarizationProtocol
typealias STTBackendExecutionDependencies = MemoraSharedCore.STTBackendExecutionDependencies
typealias STTServiceExecutionDependencies = MemoraSharedCore.STTServiceExecutionDependencies
typealias AudioSilenceProbe = MemoraSharedCore.AudioSilenceProbe
typealias CheckpointChunkResult = MemoraSharedCore.CheckpointChunkResult
typealias DurationFormatter = MemoraSharedCore.DurationFormatter
typealias OnDeviceTranscriptionTimeoutError = MemoraSharedCore.OnDeviceTranscriptionTimeoutError
typealias SpeakerSegment = MemoraSharedCore.SpeakerSegment
typealias STTBackendDiagnosticEntry = MemoraSharedCore.STTBackendDiagnosticEntry
typealias STTBackendType = MemoraSharedCore.STTBackendType
typealias STTCheckpointHooks = MemoraSharedCore.STTCheckpointHooks
typealias STTFailureCategory = MemoraSharedCore.STTFailureCategory
typealias STTLanguageNormalizer = MemoraSharedCore.STTLanguageNormalizer
typealias STTProgressThrottler = MemoraSharedCore.STTProgressThrottler
typealias StreamingTranscriptMerger = MemoraSharedCore.StreamingTranscriptMerger
typealias TranscriptPostProcessor = MemoraSharedCore.TranscriptPostProcessor
typealias TranscriptResult = MemoraSharedCore.TranscriptResult
typealias TranscriptionEstimate = MemoraSharedCore.TranscriptionEstimate
