require 'rails_helper'

RSpec.describe Enterprise::MessageTemplates::HookExecutionService do
  let(:account) { create(:account, custom_attributes: { plan_name: 'startups' }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, contact: contact, status: :pending) }

  before do
    # Link assistant to inbox
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
  end

  describe '#trigger_templates' do
    context 'when Captain assistant is configured for automatic responses' do
      let(:message) { create(:message, conversation: conversation, message_type: :incoming, content: 'Hello, I need help!') }

      before do
        # Ensure account has Captain response quota
        allow(account).to receive(:usage_limits).and_return({
          captain: {
            responses: {
              current_available: 100,
              consumed: 0
            }
          }
        })
      end

      it 'schedules Captain::Conversation::ResponseBuilderJob when conditions are met' do
        expect(Captain::Conversation::ResponseBuilderJob).to receive(:perform_later).with(conversation, assistant)

        described_class.new(message: message).perform
      end

      it 'generates automatic AI response to incoming message', :vcr do
        # Mock the AI service to avoid actual API calls
        mock_service = instance_double(Captain::Llm::AssistantChatService)
        allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:generate_response).and_return({
          'response' => 'Hello! How can I assist you today?',
          'agent_name' => nil
        })

        # Create the message which triggers the hook
        expect do
          create(:message, conversation: conversation, message_type: :incoming, content: 'I have a question')
        end.to have_enqueued_job(Captain::Conversation::ResponseBuilderJob)
      end

      context 'when conversation is not pending' do
        let(:resolved_conversation) { create(:conversation, inbox: inbox, account: account, contact: contact, status: :resolved) }
        let(:message_resolved) { create(:message, conversation: resolved_conversation, message_type: :incoming) }

        it 'does not schedule AI response for resolved conversations' do
          expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

          described_class.new(message: message_resolved).perform
        end
      end

      context 'when message is outgoing' do
        let(:outgoing_message) { create(:message, conversation: conversation, message_type: :outgoing) }

        it 'does not schedule AI response for agent messages' do
          expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

          described_class.new(message: outgoing_message).perform
        end
      end

      context 'when inbox does not have captain assistant' do
        let(:inbox_without_captain) { create(:inbox, account: account) }
        let(:conversation_no_captain) { create(:conversation, inbox: inbox_without_captain, account: account, status: :pending) }
        let(:message_no_captain) { create(:message, conversation: conversation_no_captain, message_type: :incoming) }

        it 'does not schedule AI response' do
          expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)

          described_class.new(message: message_no_captain).perform
        end
      end

      context 'when account has no available Captain responses' do
        before do
          allow(account).to receive(:usage_limits).and_return({
            captain: {
              responses: {
                current_available: 0,
                consumed: 100
              }
            }
          })
        end

        it 'performs handoff instead of generating response' do
          expect(Captain::Conversation::ResponseBuilderJob).not_to receive(:perform_later)
          expect(conversation).to receive(:bot_handoff!)

          described_class.new(message: message).perform
        end
      end

      context 'with message attachments' do
        let(:message_with_attachment) do
          msg = create(:message, conversation: conversation, message_type: :incoming, content: 'Check this image')
          msg.attachments.create!(account: account, file_type: :image)
          msg
        end

        it 'schedules AI response with delay for attachment processing' do
          expect(Captain::Conversation::ResponseBuilderJob).to receive(:set).with(wait: be >= 1.second).and_return(
            Captain::Conversation::ResponseBuilderJob
          )
          expect(Captain::Conversation::ResponseBuilderJob).to receive(:perform_later).with(conversation, assistant)

          described_class.new(message: message_with_attachment).perform
        end
      end
    end

    context 'integration with base service' do
      let(:contact_no_email) { create(:contact, email: nil, account: account) }
      let(:web_widget_inbox) { create(:inbox, account: account, greeting_enabled: true, enable_email_collect: true) }
      let(:conversation_web) { create(:conversation, inbox: web_widget_inbox, account: account, contact: contact_no_email, status: :pending) }

      it 'calls both base templates and Captain response' do
        # Link assistant to web widget inbox
        create(:captain_inbox, captain_assistant: assistant, inbox: web_widget_inbox)

        # Mock account usage limits
        allow(account).to receive(:usage_limits).and_return({
          captain: {
            responses: {
              current_available: 100,
              consumed: 0
            }
          }
        })

        greeting_service = double
        email_collect_service = double

        allow(MessageTemplates::Template::Greeting).to receive(:new).and_return(greeting_service)
        allow(greeting_service).to receive(:perform).and_return(true)
        allow(MessageTemplates::Template::EmailCollect).to receive(:new).and_return(email_collect_service)
        allow(email_collect_service).to receive(:perform).and_return(true)

        expect(Captain::Conversation::ResponseBuilderJob).to receive(:perform_later).with(conversation_web, assistant)

        message = create(:message, conversation: conversation_web, message_type: :incoming, content: 'Hi there')

        # Verify base templates were also called
        expect(MessageTemplates::Template::Greeting).to have_received(:new)
        expect(MessageTemplates::Template::EmailCollect).to have_received(:new)
      end
    end
  end

  describe 'AI response verification' do
    it 'verifies the complete automatic response flow', :aggregate_failures do
      # Setup
      allow(account).to receive(:usage_limits).and_return({
        captain: {
          responses: {
            current_available: 100,
            consumed: 0
          }
        }
      })

      # Mock AI service
      mock_service = instance_double(Captain::Llm::AssistantChatService)
      allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(mock_service)
      allow(mock_service).to receive(:generate_response).and_return({
        'response' => 'I understand you need assistance. Let me help you with that.',
        'agent_name' => nil
      })

      # Verify initial state
      expect(conversation.messages.count).to eq(0)

      # Create incoming message (simulating customer message)
      customer_message = create(:message,
        conversation: conversation,
        message_type: :incoming,
        content: 'Can you help me with my order?'
      )

      # Verify message was created
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last).to eq(customer_message)

      # Process the queued job
      perform_enqueued_jobs(only: Captain::Conversation::ResponseBuilderJob)

      # Verify AI response was created
      conversation.reload
      expect(conversation.messages.count).to eq(2)

      ai_response = conversation.messages.last
      expect(ai_response.message_type).to eq('outgoing')
      expect(ai_response.sender).to eq(assistant)
      expect(ai_response.content).to eq('I understand you need assistance. Let me help you with that.')
    end
  end
end
