# Como Testar a Resposta Automática da IA

## Resumo (Portuguese)
A funcionalidade de **resposta automática da IA já está implementada e funcionando** no Chatwoot através do recurso **Captain** (Edição Enterprise).

## Como Funciona

A IA responde automaticamente às mensagens quando TODAS as condições são atendidas:
1. ✅ **Status da conversa**: `pending` (não resolvida)
2. ✅ **Tipo de mensagem**: `incoming` (do cliente)
3. ✅ **Configuração da caixa de entrada**: Tem um `captain_assistant` atribuído
4. ✅ **Limites da conta**: Tem quota disponível de respostas Captain

## Como Configurar

### 1. Criar um Assistente Captain
No painel administrativo:
- Navegue até a seção Captain
- Crie um novo assistente
- Configure:
  - Nome do assistente
  - Descrição
  - Temperatura (criatividade da IA)
  - Diretrizes de resposta
  - Guardrails (restrições de segurança)

### 2. Vincular Assistente à Caixa de Entrada
- Selecione a caixa de entrada (inbox)
- Associe o assistente Captain criado
- Isso cria um registro `CaptainInbox` vinculando os dois

### 3. Verificar Quota da Conta
- Certifique-se de que a conta tem respostas Captain disponíveis
- Verifique em `account.usage_limits[:captain][:responses][:current_available]`

## Fluxo de Resposta Automática

```
Cliente envia mensagem
        ↓
Message#after_create_commit
        ↓
execute_message_template_hooks
        ↓
MessageTemplates::HookExecutionService#perform
        ↓
Enterprise::MessageTemplates::HookExecutionService#trigger_templates
        ↓
Verifica condições (pending? incoming? captain_active?)
        ↓
Captain::Conversation::ResponseBuilderJob.perform_later
        ↓
Coleta histórico de mensagens
        ↓
Captain::Llm::AssistantChatService#generate_response
        ↓
Chama API OpenAI com contexto
        ↓
Cria mensagem de resposta (outgoing)
        ↓
Incrementa contador de uso
```

## Testes

### Executar Testes Específicos

```bash
# Teste do serviço de geração de resposta
bundle exec rspec spec/enterprise/jobs/captain/conversation/response_builder_job_spec.rb

# Teste do hook de execução (novo teste criado)
bundle exec rspec spec/enterprise/services/enterprise/message_templates/hook_execution_service_spec.rb
```

### Teste Manual

1. Configure um assistente Captain
2. Vincule-o a uma caixa de entrada
3. Envie uma mensagem de teste como cliente
4. Verifique se a IA responde automaticamente

## Componentes Principais

### Modelos
- `Captain::Assistant` - Configuração do assistente IA
- `CaptainInbox` - Vincula assistentes a caixas de entrada
- `Message` - Mensagens com gatilhos de resposta IA

### Serviços
- `Captain::Llm::AssistantChatService` - Integração com OpenAI
- `Captain::ToolRegistryService` - Gerencia ferramentas da IA
- `Captain::Llm::SystemPromptsService` - Gera prompts do sistema

### Jobs
- `Captain::Conversation::ResponseBuilderJob` - Geração assíncrona de respostas

## Recursos Especiais

### Busca em FAQ
- Assistentes podem pesquisar documentação
- Armazenado na tabela `captain_documents`
- Usa embeddings para busca semântica

### Transferência para Humano (Handoff)
- IA pode transferir para agentes humanos
- Quando não consegue ajudar
- Baseado no contexto da conversa

### Suporte Multi-modal
- Suporta imagens em mensagens
- Processa anexos com delays
- Envia dados de imagem para modelos com visão

## Conclusão

✅ **A funcionalidade de resposta automática da IA está totalmente implementada e operacional.**

Nenhuma implementação adicional é necessária - o recurso já existe e funciona conforme esperado.

---

# How to Test AI Automatic Responses (English)

## Summary
The **AI automatic response functionality is already implemented and working** in Chatwoot through the **Captain** feature (Enterprise Edition).

## How It Works

The AI automatically responds to messages when ALL conditions are met:
1. ✅ **Conversation status**: `pending` (not resolved)
2. ✅ **Message type**: `incoming` (from customer)
3. ✅ **Inbox configuration**: Has a `captain_assistant` assigned
4. ✅ **Account limits**: Has available Captain response quota

## Setup Instructions

### 1. Create a Captain Assistant
In the admin panel:
- Navigate to Captain section
- Create a new assistant
- Configure:
  - Assistant name
  - Description
  - Temperature (AI creativity)
  - Response guidelines
  - Guardrails (safety constraints)

### 2. Link Assistant to Inbox
- Select the inbox
- Associate the created Captain assistant
- This creates a `CaptainInbox` record linking them

### 3. Verify Account Quota
- Ensure account has available Captain responses
- Check `account.usage_limits[:captain][:responses][:current_available]`

## Running Tests

```bash
# Test response builder service
bundle exec rspec spec/enterprise/jobs/captain/conversation/response_builder_job_spec.rb

# Test hook execution service (newly created)
bundle exec rspec spec/enterprise/services/enterprise/message_templates/hook_execution_service_spec.rb
```

## Conclusion

✅ **AI automatic response functionality is fully implemented and operational.**

No additional implementation needed - the feature already exists and works as expected.
