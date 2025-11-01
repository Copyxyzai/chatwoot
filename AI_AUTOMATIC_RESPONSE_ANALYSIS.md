# AI Automatic Response Analysis

## Summary
The AI automatic response functionality **is already implemented and working** in Chatwoot through the **Captain** feature (Enterprise Edition).

## How It Works

### 1. Message Flow
When a new message is created in the system:
1. `Message#after_create_commit` triggers `execute_after_create_commit_callbacks`
2. This calls `execute_message_template_hooks`
3. Which invokes `MessageTemplates::HookExecutionService#perform`

### 2. Captain Integration (Enterprise)
The Enterprise edition extends the base service through `Enterprise::MessageTemplates::HookExecutionService`:

```ruby
# enterprise/app/services/enterprise/message_templates/hook_execution_service.rb
module Enterprise::MessageTemplates::HookExecutionService
  def trigger_templates
    super
    return unless should_process_captain_response?
    return perform_handoff unless inbox.captain_active?

    schedule_captain_response
  end
end
```

### 3. Conditions for AI Auto-Response
The AI responds automatically when ALL conditions are met:
- **Conversation status**: `pending` (not resolved or snoozed)
- **Message type**: `incoming` (from customer, not agent)
- **Inbox configuration**: Has a `captain_assistant` assigned
- **Account limits**: Has available Captain response quota

### 4. Response Generation Process
When conditions are met:
1. `Captain::Conversation::ResponseBuilderJob` is scheduled
2. Job collects message history from the conversation
3. Calls `Captain::Llm::AssistantChatService` (v1) or `Captain::Assistant::AgentRunnerService` (v2)
4. Uses OpenAI API to generate contextual response
5. Creates outgoing message with AI-generated content
6. Increments account usage counter

### 5. Key Components

#### Models
- `Captain::Assistant` - AI assistant configuration
- `CaptainInbox` - Links assistants to specific inboxes
- `Message` - Messages with AI response triggers

#### Services
- `Captain::Llm::AssistantChatService` - OpenAI integration for response generation
- `Captain::ToolRegistryService` - Manages AI tools (FAQ lookup, handoff, etc.)
- `Captain::Llm::SystemPromptsService` - Generates system prompts for AI

#### Jobs
- `Captain::Conversation::ResponseBuilderJob` - Async response generation

#### Configuration
Assistants have configurable properties:
- `name` - Assistant name
- `description` - Assistant purpose
- `temperature` - AI creativity level
- `response_guidelines` - Response formatting rules
- `guardrails` - Safety constraints
- `product_name` - Product context for responses

### 6. Special Features

#### FAQ Lookup
Assistants can search documentation:
- Stored in `captain_documents` table
- Uses embeddings for semantic search
- Provides context-aware answers

#### Handoff Mechanism
AI can transfer to human agents:
- When unable to help
- Based on conversation context
- Creates handoff message
- Changes conversation status to `bot_handoff`

#### Multi-modal Support
Supports images in messages:
- Processes attachments with delays
- Sends image data to vision-capable models
- Provides context from visual content

## Testing

The functionality is covered by comprehensive tests:
- `spec/enterprise/jobs/captain/conversation/response_builder_job_spec.rb`
- Integration with message lifecycle
- Both v1 and v2 implementations tested

## Configuration

To enable AI auto-response:
1. Create a Captain Assistant in the account
2. Assign the assistant to an inbox via `CaptainInbox`
3. Ensure account has available Captain response quota
4. Conversations will auto-respond when in `pending` status

## Conclusion

✅ **The AI automatic response functionality is fully implemented and operational.**

The system automatically generates AI-powered responses to incoming customer messages when:
- An assistant is configured for the inbox
- The conversation is in pending status
- Account has available quota

No additional implementation is needed - the feature already exists and works as expected.
