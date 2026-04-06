const axios = require("axios");

// ============================================
// Proj-Chat - Follow-up Worker
// ============================================
// Envia mensagens de follow-up automáticas para
// conversas resolvidas sem retorno do lead.

const CONFIG = {
  chatwoot: {
    apiUrl: process.env.CHATWOOT_API_URL || "http://chatwoot-rails:3000",
    apiToken: process.env.CHATWOOT_API_TOKEN,
    accountId: process.env.CHATWOOT_ACCOUNT_ID || "1",
  },
  evolution: {
    apiUrl: process.env.EVOLUTION_API_URL || "http://evolution-api:8080",
    apiKey: process.env.EVOLUTION_API_KEY,
    instanceName: process.env.EVOLUTION_INSTANCE_NAME || "proj-chat-principal",
  },
  intervalMs: parseInt(process.env.FOLLOWUP_INTERVAL_MS) || 1800000, // 30 min
  day1Hours: parseInt(process.env.FOLLOWUP_DAY1_HOURS) || 24,
  day3Hours: parseInt(process.env.FOLLOWUP_DAY3_HOURS) || 72,
  day7Hours: parseInt(process.env.FOLLOWUP_DAY7_HOURS) || 168,
};

const FOLLOWUP_MESSAGES = {
  day1: (name) =>
    `Olá${name ? `, ${name}` : ""}! Aqui é do escritório Proj-Chat Jurídico. Gostaríamos de saber se restou alguma dúvida sobre nosso atendimento. Estamos à disposição! 😊`,
  day3: (name) =>
    `Olá${name ? `, ${name}` : ""}! Notamos que ainda não retornou. Podemos ajudar com algo mais? Responda essa mensagem a qualquer momento.`,
  day7: (name) =>
    `Olá${name ? `, ${name}` : ""}! Essa é nossa última tentativa de contato. Quando precisar de orientação jurídica, estamos aqui. Conte conosco! 🤝`,
};

const SKIP_LABELS = ["clientes-fechados", "planejamento-fechado"];

const chatwootApi = axios.create({
  baseURL: `${CONFIG.chatwoot.apiUrl}/api/v1/accounts/${CONFIG.chatwoot.accountId}`,
  headers: {
    api_access_token: CONFIG.chatwoot.apiToken,
    "Content-Type": "application/json",
  },
});

const evolutionApi = axios.create({
  baseURL: CONFIG.evolution.apiUrl,
  headers: {
    apikey: CONFIG.evolution.apiKey,
    "Content-Type": "application/json",
  },
});

function hoursSinceResolved(conversation) {
  const resolvedAt = new Date(
    conversation.resolved_at || conversation.last_activity_at
  );
  return (Date.now() - resolvedAt.getTime()) / (1000 * 60 * 60);
}

function hasLabel(conversation, label) {
  return (conversation.labels || []).includes(label);
}

function shouldSkip(conversation) {
  return SKIP_LABELS.some((label) => hasLabel(conversation, label));
}

function getFollowupStage(conversation) {
  const hours = hoursSinceResolved(conversation);

  if (hasLabel(conversation, "followup-sent-3")) return null; // já enviou todos
  if (hasLabel(conversation, "followup-sent-2") && hours >= CONFIG.day7Hours)
    return { stage: 3, message: FOLLOWUP_MESSAGES.day7 };
  if (hasLabel(conversation, "followup-sent-1") && hours >= CONFIG.day3Hours)
    return { stage: 2, message: FOLLOWUP_MESSAGES.day3 };
  if (!hasLabel(conversation, "followup-sent-1") && hours >= CONFIG.day1Hours)
    return { stage: 1, message: FOLLOWUP_MESSAGES.day1 };

  return null;
}

async function getResolvedConversations() {
  try {
    const response = await chatwootApi.get("/conversations", {
      params: { status: "resolved", page: 1 },
    });
    return response.data.data?.payload || [];
  } catch (error) {
    console.error("Erro ao buscar conversas:", error.message);
    return [];
  }
}

async function getContactPhone(contactId) {
  try {
    const response = await chatwootApi.get(`/contacts/${contactId}`);
    const contact = response.data;
    return {
      phone: contact.phone_number,
      name: contact.name,
    };
  } catch (error) {
    console.error(`Erro ao buscar contato ${contactId}:`, error.message);
    return null;
  }
}

async function sendWhatsAppMessage(phone, text) {
  // Remove caracteres não numéricos e garante formato correto
  const cleanPhone = phone.replace(/\D/g, "");
  try {
    await evolutionApi.post(
      `/message/sendText/${CONFIG.evolution.instanceName}`,
      {
        number: cleanPhone,
        text: text,
      }
    );
    console.log(`Mensagem enviada para ${cleanPhone}`);
    return true;
  } catch (error) {
    console.error(`Erro ao enviar para ${cleanPhone}:`, error.message);
    return false;
  }
}

async function addLabel(conversationId, label) {
  try {
    // Busca labels atuais
    const conv = await chatwootApi.get(`/conversations/${conversationId}`);
    const currentLabels = conv.data.labels || [];

    await chatwootApi.post(`/conversations/${conversationId}/labels`, {
      labels: [...currentLabels, label],
    });
  } catch (error) {
    console.error(
      `Erro ao adicionar label ${label} na conversa ${conversationId}:`,
      error.message
    );
  }
}

async function processFollowups() {
  console.log(`[${new Date().toISOString()}] Verificando follow-ups...`);

  const conversations = await getResolvedConversations();
  let sent = 0;

  for (const conversation of conversations) {
    if (shouldSkip(conversation)) continue;

    const followup = getFollowupStage(conversation);
    if (!followup) continue;

    const contactId =
      conversation.meta?.sender?.id || conversation.contact?.id;
    if (!contactId) continue;

    const contact = await getContactPhone(contactId);
    if (!contact || !contact.phone) continue;

    const messageText = followup.message(contact.name);
    const success = await sendWhatsAppMessage(contact.phone, messageText);

    if (success) {
      await addLabel(conversation.id, `followup-sent-${followup.stage}`);
      sent++;
      console.log(
        `  Follow-up ${followup.stage} enviado para ${contact.name || contact.phone} (conversa #${conversation.id})`
      );
    }

    // Delay entre envios para não sobrecarregar
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  console.log(
    `[${new Date().toISOString()}] ${sent} follow-ups enviados de ${conversations.length} conversas verificadas.`
  );
}

// ============================================
// Inicialização
// ============================================
console.log("============================================");
console.log("  Proj-Chat Follow-up Worker");
console.log("============================================");
console.log(`Chatwoot API: ${CONFIG.chatwoot.apiUrl}`);
console.log(`Evolution API: ${CONFIG.evolution.apiUrl}`);
console.log(`Instância: ${CONFIG.evolution.instanceName}`);
console.log(`Intervalo: ${CONFIG.intervalMs / 60000} minutos`);
console.log(
  `Follow-ups: ${CONFIG.day1Hours}h / ${CONFIG.day3Hours}h / ${CONFIG.day7Hours}h`
);
console.log("============================================");

// Executa imediatamente e depois no intervalo
processFollowups();
setInterval(processFollowups, CONFIG.intervalMs);
