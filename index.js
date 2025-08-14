// index.js
require('dotenv').config();
const fs = require('fs');
const { Client, GatewayIntentBits, Partials, ActionRowBuilder, ButtonBuilder, ButtonStyle, EmbedBuilder, PermissionFlagsBits } = require('discord.js');
const fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args));

const config = require('./config.json');

const BOT_TOKEN = process.env.BOT_TOKEN;
const OPENAI_KEY = process.env.OPENAI_KEY;

const PANEL_CHANNEL_ID = config.panelChannelId;
const TICKETS_CATEGORY_ID = config.ticketsCategoryId;
const ADMIN_ROLE_IDS = config.adminRoleIds || [];
const TICKET_PREFIX = config.ticketNamePrefix || 'ticket-';
const MOD_CHANNEL_ID = config.modChannelId;
const WHITELIST_USERS = config.whitelistUsers || [];

if (!PANEL_CHANNEL_ID || !TICKETS_CATEGORY_ID) {
  console.error('Заполни config.json: panelChannelId, ticketsCategoryId');
  process.exit(1);
}

const TICKETS_FILE = './tickets.json';
let tickets = {};
if (fs.existsSync(TICKETS_FILE)) {
  try { tickets = JSON.parse(fs.readFileSync(TICKETS_FILE, 'utf8')); } catch { tickets = {}; }
}
function saveTickets() {
  fs.writeFileSync(TICKETS_FILE, JSON.stringify(tickets, null, 2));
}

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent, GatewayIntentBits.GuildMembers],
  partials: [Partials.Channel]
});

const ticketState = new Map();

const FAQ_TEXT = `
Вы — помощник поддержки Essence Client. Отвечай кратко и по делу. Если вопрос точно совпадает с FAQ, используй готовые ответы.
FAQ:
> Как зарегистрироваться на сайте и приобрести клиент?
Для того чтобы зарегистрироваться на сайте клиента, Вам необходимо приобрести клиент, это вы можете сделать через https://essencepenit.fun. После приобретения вы получите ключ авторизации для регистрации аккаунта. Мы принимаем способы оплаты такие как - Криптовалюту, рубли, гривны, доллары, по поводу остальных обращайтесь в тикеты. 

> Как приобрести клиент из Украины или других стран?
Гайд по приобретению (рассказано про все) https://youtu.be/uZOEVoZg2cY

> Как установить конфиг?
Вы можете прописать .cfg dir, у вас откроется папка, туда Вы должны переместить конфиг. Второй вариант, Вы можете вручную открыть папку - C:\\Sk3dGuardNew\\clients\\Essence\\essence\\cfg , и сюда переместить конфиг.

> У меня проблема, что делать?
Если у Вас появилась какая либо проблема, Вы можете обратиться в тикеты за помощью.

> Я ютубер, хочу подать на ютубера
Критерии: 1) На всех ваших видео должно быть более 300 просмотров. 2) Контент связан с хвх майнкрафтом. 3) Последнее видео опубликовано не более 7 дней назад. Если вы подходите, отправьте ссылку на ваш канал пожалуйста, и нажмите кнопку "Эскалировать" 

> Я тиктокер, хочу стать тиктокером
Критерии: 1) На всех ваших видео более 700 просмотров. 2) Контент связан с хвх майнкрафтом. 3) Последнее видео опубликовано не более 3 дней назад. Если вы подходите, отправьте ссылку на ваш канал пожалуйста, и нажмите кнопку "Эскалировать".
> Нашел баг, что делать?
Сообщить в канал багов.

> Что такое роль <@&1321824495228686356> и как её получить?
Роль выдаётся тем, кто приобрёл клиент. Получить можно отправив скрин с сайта на фоне дискорда в канал тикетов.

> Ввожу данные в лаунчер идет загрузка и вылетает
Решение: Выключи запрет дс/ютуб и запускайся без него, если не получилось пробуй запускаться с впном

> Долгая загрузка (показывает 0%)
Решение: Жди пока скачается, это из-за впна

> После нажатия кнопки Launch the game лоадер закрывается и не запускается майнкрафт
Решение: Установи https://aka.ms/vs/17/release/vc_redist.x64.exe

> Если возникли проблемы с настройкой конфига и т.п, можно приобрести конфиг владельца на https://funpay.com/users/6885080/

> Не видно некоторых элементов худа
Через elements()C:\\Sk3dGuardNew\\clients\\Essence\\Essence) дать ему положение того худа который видишь, например не видно таргет худ, даешь ему положение поушенов, и перезапускаешь клиент.

> Клиент можно приобрести за валюту на серверах, таких как Funtime, Spookytime, для этого нажми кнопку "Эскалировать".

> Иногда на сайте перестает работать платежная система, в данном случае вы можете оплатить через этот канал
Вы можете приобрести подписку:
На сайте - https://essencepenit.fun/products
Переводом на карту: 2200701728619559
Переводом по СБП: +79952544623 Т-Банк, Роман С.
На FunPay - Приобрести нельзя, но можно вывести деньги сразу на нашу карту/сбп (комиссия на вас)

Цена на товары в разной валюте
Навсегда - 599 рублей
3 месяца - 449 рублей
Месяц - 299 рублей
Сброс хвида - 249 рублей

Промокоды не распространяются на товары до 300 рублей. Для оплаты в другой валюте необходимо эскалировать тикет.

Пожалуйста, обратите внимание, что техническая поддержка не занимается настройкой клиента, предоставлением конфигураций, тем, а также разъяснением работы каждого модуля. Не нужно в тикеты писать ваши идеи, для этого есть специальный канал.
`;

const ESCALATION_KEYWORDS = [
  "I don't know", "I do not know", "I’m not sure", "I'm not sure",
  "I cannot", "I can't", "I don't have", "I do not have", "не могу", "не знаю"
];

client.once('ready', async () => {
  console.log(`Logged in as ${client.user.tag}`);
  try {
    const panelChannel = await client.channels.fetch(PANEL_CHANNEL_ID);
    if (!panelChannel) { console.error('Панельный канал не найден'); return; }
    const embed = new EmbedBuilder()
      .setTitle('Нужна помощь?')
      .setDescription('Нажми кнопку ниже, чтобы открыть приватный тикет с нашей службой поддержки.')
      .setFooter({ text: 'Essence Client Support' });
    const openRow = new ActionRowBuilder()
      .addComponents(
        new ButtonBuilder()
          .setCustomId('open_ticket')
          .setLabel('📩 Открыть тикет')
          .setStyle(ButtonStyle.Primary)
      );
    await panelChannel.send({ embeds: [embed], components: [openRow] });
    console.log('Panel sent.');
  } catch (err) {
    console.error('Ошибка при отправке панели:', err);
  }
});

client.on('interactionCreate', async (interaction) => {
  if (interaction.isButton()) {
    if (interaction.customId === 'open_ticket') {
      await handleOpenTicket(interaction);
    } else if (interaction.customId === 'escalate_ticket') {
      await handleEscalate(interaction);
    } else if (interaction.customId === 'close_ticket') {
      await handleClose(interaction);
    } else if (interaction.customId === 'confirm_close_ticket') {
      await handleConfirmClose(interaction);
    } else if (interaction.customId === 'cancel_close_ticket') {
      await interaction.reply({ content: 'Закрытие отменено.', ephemeral: true }).catch(async () => {
        await interaction.editReply({ content: 'Закрытие отменено.', ephemeral: true }).catch(() => {});
      });
    } else if (interaction.customId.startsWith('take_ticket:')) {
      const channelId = interaction.customId.split(':')[1];
      await handleTakeTicket(interaction, channelId);
    } else if (interaction.customId.startsWith('transfer_ticket:')) {
      const channelId = interaction.customId.split(':')[1];
      await handleTransferTicket(interaction, channelId);
    }
  }
});

client.on('messageCreate', async (message) => {
  if (message.author.bot) return;

  const ch = message.channel;
  const ticket = tickets[ch.id];
  if (ticket) {
    const allowed = new Set([ticket.authorId, ticket.ownerId, ...WHITELIST_USERS.filter(Boolean)]);
    if (!allowed.has(message.author.id)) {
      await message.delete().catch(() => {});
      return;
    }
  }

  if (ch.isTextBased && ticketState.has(ch.id)) {
    const state = ticketState.get(ch.id);
    if (state.disabled) {
      return;
    }
    await message.channel.sendTyping();
    try {
      const gptAnswer = await askOpenAI(message.content, message.author.tag);
      await message.channel.send({ content: `**Support (GPT):**\n${gptAnswer}` });
      const lower = gptAnswer.toLowerCase();
      const needsEscalation = ESCALATION_KEYWORDS.some(k => lower.includes(k.toLowerCase()));
      if (needsEscalation) {
        const escalateRow = new ActionRowBuilder()
          .addComponents(
            new ButtonBuilder()
              .setCustomId('escalate_ticket')
              .setLabel('🔔 Эскалировать (пинг админов)')
              .setStyle(ButtonStyle.Danger),
            new ButtonBuilder()
              .setCustomId('close_ticket')
              .setLabel('🔒 Закрыть тикет')
              .setStyle(ButtonStyle.Secondary)
          );
        await message.channel.send({ content: 'К сожалению, я не уверен в ответе — хочешь, я пингну админов?', components: [escalateRow] });
      } else {
        const closeRow = new ActionRowBuilder()
          .addComponents(
            new ButtonBuilder()
              .setCustomId('close_ticket')
              .setLabel('🔒 Закрыть тикет')
              .setStyle(ButtonStyle.Secondary)
          );
        await message.channel.send({ content: 'Если всё помогло — закрой тикет.', components: [closeRow] });
      }
    } catch (err) {
      console.error('OpenAI error:', err);
      await message.channel.send('Ошибка при обращении к службе поддержки. Попробуй ещё раз или эскалируй тикет.');
    }
  }
});

async function handleOpenTicket(interaction) {
  await interaction.deferReply({ ephemeral: true }).catch(() => {});
  try {
    const guild = interaction.guild;
    if (!guild) { await interaction.editReply('Ошибка: команда работает только в сервере.'); return; }

    const existing = guild.channels.cache.find(c =>
      c.name === `${TICKET_PREFIX}${interaction.user.username.toLowerCase()}` &&
      c.parentId === TICKETS_CATEGORY_ID
    );
    if (existing) {
      await interaction.editReply({ content: `У тебя уже есть тикет: ${existing}`, ephemeral: true });
      return;
    }

    const channelName = `${TICKET_PREFIX}${interaction.user.username.toLowerCase()}`.replace(/[^a-z0-9-]/gi, '-').slice(0, 90);

    const everyonePerm = { id: guild.roles.everyone.id, deny: [PermissionFlagsBits.ViewChannel] };
    const creatorPerm = { id: interaction.user.id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory] };
    const adminPerms = ADMIN_ROLE_IDS.map(id => ({ id, allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages, PermissionFlagsBits.ReadMessageHistory] }));

    const channel = await guild.channels.create({
      name: channelName,
      type: 0,
      parent: TICKETS_CATEGORY_ID,
      permissionOverwrites: [everyonePerm, creatorPerm, ...adminPerms]
    });

    ticketState.set(channel.id, { disabled: false, creatorId: interaction.user.id });
    tickets[channel.id] = { authorId: interaction.user.id, ownerId: null };
    saveTickets();

    const embed = new EmbedBuilder()
      .setTitle('Тикет открыт')
      .setDescription(`Привет, <@${interaction.user.id}>! Опиши свою проблему — я попробую помочь автоматически.`)
      .setFooter({ text: 'Нажми «🔒 Закрыть тикет», когда вопрос будет решён.' });

    const row = new ActionRowBuilder()
      .addComponents(
        new ButtonBuilder()
          .setCustomId('escalate_ticket')
          .setLabel('🔔 Эскалировать (пинг админов)')
          .setStyle(ButtonStyle.Danger),
        new ButtonBuilder()
          .setCustomId('close_ticket')
          .setLabel('🔒 Закрыть тикет')
          .setStyle(ButtonStyle.Secondary)
      );

    const mentionRoles = ADMIN_ROLE_IDS.length ? ` <@&${ADMIN_ROLE_IDS.join('> <@&')}>` : '';
    await channel.send({ content: `<@${interaction.user.id}>${mentionRoles}`, embeds: [embed], components: [row] }).catch(() => {
      channel.send({ embeds: [embed], components: [row] });
    });

    await interaction.editReply({ content: `Твой тикет создан: ${channel}`, ephemeral: true });
  } catch (err) {
    console.error('handleOpenTicket error:', err);
    await interaction.editReply({ content: 'Ошибка при создании тикета.', ephemeral: true });
  }
}

async function handleEscalate(interaction) {
  await interaction.deferReply({ ephemeral: true }).catch(() => {});
  try {
    const ch = interaction.channel;
    if (!ch) { await interaction.editReply('Ошибка: не удалось определить канал.'); return; }
    if (!ticketState.has(ch.id)) { await interaction.editReply('Это не тикет-канал.'); return; }

    const state = ticketState.get(ch.id);
    state.disabled = true;
    ticketState.set(ch.id, state);

    const ticket = tickets[ch.id] || { authorId: state.creatorId || interaction.user.id, ownerId: null };
    tickets[ch.id] = ticket;
    saveTickets();

    await ch.send({ content: 'Эскалация отправлена модераторам. Ожидайте принятия тикета.' });

    if (MOD_CHANNEL_ID) {
      const modCh = await client.channels.fetch(MOD_CHANNEL_ID).catch(() => null);
      if (modCh) {
        const embed = new EmbedBuilder()
          .setTitle('Эскалация тикета')
          .setDescription(`Канал: <#${ch.id}>\nАвтор: <@${ticket.authorId}>\nНажмите, чтобы взять тикет.`)
          .setColor(0xff7a00);
        const row = new ActionRowBuilder().addComponents(
          new ButtonBuilder().setCustomId(`take_ticket:${ch.id}`).setLabel('Взять тикет').setStyle(ButtonStyle.Primary)
        );
        await modCh.send({ embeds: [embed], components: [row] });
      }
    }

    await interaction.editReply({ content: 'Админы уведомлены, автоответы отключены в этом тикете.', ephemeral: true });
  } catch (err) {
    console.error('handleEscalate error:', err);
    await interaction.editReply({ content: 'Ошибка при эскалации.', ephemeral: true });
  }
}

async function handleTakeTicket(interaction, channelId) {
  await interaction.deferReply({ ephemeral: true }).catch(() => {});
  try {
    if (!tickets[channelId]) { await interaction.editReply({ content: 'Тикет не найден.', ephemeral: true }); return; }
    tickets[channelId].ownerId = interaction.user.id;
    saveTickets();

    const tChannel = await client.channels.fetch(channelId).catch(() => null);
    if (tChannel) {
      const row = new ActionRowBuilder().addComponents(
        new ButtonBuilder().setCustomId(`transfer_ticket:${channelId}`).setLabel('Передать тикет').setStyle(ButtonStyle.Secondary),
        new ButtonBuilder().setCustomId('close_ticket').setLabel('🔒 Закрыть тикет').setStyle(ButtonStyle.Secondary)
      );
      await tChannel.send({ content: `Тикет взял <@${interaction.user.id}>. Пишут только автор тикета и назначенный модератор.`, components: [row] });
    }

    if (interaction.message && interaction.message.edit) {
      const disabledRow = new ActionRowBuilder().addComponents(
        new ButtonBuilder().setCustomId(`take_ticket:${channelId}`).setLabel('Взят').setStyle(ButtonStyle.Success).setDisabled(true)
      );
      await interaction.message.edit({ components: [disabledRow] }).catch(() => {});
    }

    await interaction.editReply({ content: 'Тикет назначен на вас.', ephemeral: true });
  } catch (err) {
    console.error('handleTakeTicket error:', err);
    await interaction.editReply({ content: 'Ошибка при назначении тикета.', ephemeral: true });
  }
}

async function handleTransferTicket(interaction, channelId) {
  await interaction.deferReply({ ephemeral: true }).catch(() => {});
  try {
    const t = tickets[channelId];
    if (!t) { await interaction.editReply({ content: 'Тикет не найден.', ephemeral: true }); return; }
    if (interaction.user.id !== t.ownerId) { await interaction.editReply({ content: 'Передавать может только текущий владелец тикета.', ephemeral: true }); return; }

    const tChannel = await client.channels.fetch(channelId).catch(() => null);
    if (!tChannel) { await interaction.editReply({ content: 'Канал тикета не найден.', ephemeral: true }); return; }

    await interaction.editReply({ content: 'Отправьте в этот канал ID пользователя или упоминание нового модератора в течение 30 секунд.', ephemeral: true });

    const filter = m => m.author.id === interaction.user.id;
    const collected = await tChannel.awaitMessages({ filter, max: 1, time: 30000 }).catch(() => null);
    if (!collected || !collected.size) { await tChannel.send('Передача отменена: время истекло.'); return; }

    const msg = collected.first();
    const mention = msg.mentions.users.first();
    const newId = mention ? mention.id : (msg.content.match(/\d{15,20}/)?.[0] || null);
    if (!newId) { await tChannel.send('Не удалось распознать ID пользователя. Повторите попытку.'); return; }

    t.ownerId = newId;
    tickets[channelId] = t;
    saveTickets();

    await tChannel.send(`Тикет передан <@${newId}>.`);
  } catch (err) {
    console.error('handleTransferTicket error:', err);
    try { await interaction.editReply({ content: 'Ошибка при передаче тикета.', ephemeral: true }); } catch {}
  }
}

async function handleClose(interaction) {
  await interaction.deferReply({ ephemeral: true }).catch(() => {});
  try {
    const ch = interaction.channel;
    if (!ch || !ticketState.has(ch.id)) {
      await interaction.editReply({ content: 'Это не тикет-канал.', ephemeral: true });
      return;
    }
    const confirmRow = new ActionRowBuilder()
      .addComponents(
        new ButtonBuilder()
          .setCustomId('confirm_close_ticket')
          .setLabel('Подтвердить закрытие')
          .setStyle(ButtonStyle.Danger),
        new ButtonBuilder()
          .setCustomId('cancel_close_ticket')
          .setLabel('Отмена')
          .setStyle(ButtonStyle.Secondary)
      );
    await interaction.editReply({ content: 'Нажми кнопку подтверждения для закрытия тикета.', ephemeral: true });
    await ch.send({ content: `${interaction.user} предлагает закрыть тикет. Подтвердите:`, components: [confirmRow] });
  } catch (err) {
    console.error('handleClose error:', err);
    await interaction.editReply({ content: 'Ошибка при попытке закрыть тикет.', ephemeral: true });
  }
}

async function handleConfirmClose(interaction) {
  await interaction.deferReply({ ephemeral: true }).catch(() => {});
  try {
    const ch = interaction.channel;
    if (!ch || !ticketState.has(ch.id)) {
      await interaction.editReply({ content: 'Это не тикет-канал.', ephemeral: true });
      return;
    }
    await ch.send('Тикет закрыт. Канал будет удалён через 3 секунды.').catch(() => {});
    setTimeout(async () => {
      try {
        ticketState.delete(ch.id);
        if (tickets[ch.id]) { delete tickets[ch.id]; saveTickets(); }
        await ch.delete('Ticket closed');
      } catch (err) {
        console.error('Ошибка удаления канала:', err);
      }
    }, 3000);

    await interaction.editReply({ content: 'Тикет закрыт.', ephemeral: true });
  } catch (err) {
    console.error('handleConfirmClose error:', err);
    await interaction.editReply({ content: 'Ошибка при подтверждении закрытия.', ephemeral: true });
  }
}

async function askOpenAI(userContent, username) {
  const messages = [
    { role: 'system', content: `You are Essence Client support assistant. Use the following FAQ as reference:\n\n${FAQ_TEXT}\n\nAnswer in Russian. Be concise, actionable, and include step-by-step instructions when required. If the question is out-of-scope or you are not sure, say so and suggest escalation.` },
    { role: 'user', content: `${userContent}\n\nUser: ${username}` }
  ];

  const payload = {
    model: 'gpt-4o-mini',
    messages,
    max_tokens: 700,
    temperature: 0.1
  };

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`OpenAI API error: ${res.status} ${text}`);
  }
  const data = await res.json();
  const content = data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content;
  if (!content) throw new Error('No content from OpenAI');
  return content.trim();
}

process.on('unhandledRejection', (err) => {
  console.error('UnhandledRejection', err);
});

client.login(BOT_TOKEN);
