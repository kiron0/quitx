(() => {
  const A = window.QX_ASSETS || '../site/assets/';

  const S = {
    power: '<svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M6 1.3v4.2M3.4 2.9a4 4 0 1 0 5.2 0"/></svg>',
    bolt: '<svg viewBox="0 0 13 16"><path d="M8 0L0 9.2h5.2L4.4 16 13 6.4H7.6z" fill="currentColor"/></svg>',
    more: '<svg viewBox="0 0 12 12" fill="currentColor"><circle cx="2.2" cy="6" r="1.1"/><circle cx="6" cy="6" r="1.1"/><circle cx="9.8" cy="6" r="1.1"/></svg>',
    gear: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="2.2"/><path d="M8 1.5v1.8M8 12.7v1.8M1.5 8h1.8M12.7 8h1.8M3.4 3.4l1.3 1.3M11.3 11.3l1.3 1.3M3.4 12.6l1.3-1.3M11.3 4.7l1.3-1.3"/></svg>',
    search: '<svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="5" cy="5" r="3.6"/><path d="M7.8 7.8l2.8 2.8" stroke-linecap="round"/></svg>',
    check: '<svg viewBox="0 0 12 12"><circle cx="6" cy="6" r="6" fill="#fff"/><path d="M3.3 6.2l1.8 1.8 3.6-3.8" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    question: '<svg viewBox="0 0 28 28"><circle cx="14" cy="14" r="13" fill="#FEBC33"/><path d="M10.6 10.8a3.5 3.5 0 1 1 4.6 3.3c-.8.3-1.2.9-1.2 1.7v.6" fill="none" stroke="#2B1D00" stroke-width="2.4" stroke-linecap="round"/><circle cx="14" cy="20.4" r="1.5" fill="#2B1D00"/></svg>',
    warn: '<svg viewBox="0 0 28 28"><path d="M14 2.5l12.5 22H1.5z" fill="#FF453A" stroke="#FF453A" stroke-width="2" stroke-linejoin="round"/><path d="M14 10v7" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><circle cx="14" cy="21" r="1.5" fill="#fff"/></svg>',
    gauge: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M2.2 12a6.3 6.3 0 1 1 11.6 0"/><path d="M8 9.5l3-3"/></svg>',
    cpu: '<svg viewBox="0 0 16 16"><rect x="3.5" y="3.5" width="9" height="9" rx="1.6"/><rect x="6" y="6" width="4" height="4" rx=".6"/><path d="M6 1.5v2M10 1.5v2M6 12.5v2M10 12.5v2M1.5 6h2M1.5 10h2M12.5 6h2M12.5 10h2"/></svg>',
    mem: '<svg viewBox="0 0 16 16"><rect x="1.5" y="4.5" width="13" height="6.5" rx="1"/><path d="M4 7v1.5M6.5 7v1.5M9 7v1.5M11.5 7v1.5M3 11v2M6 11v2M10 11v2M13 11v2"/></svg>',
    gpu: '<svg viewBox="0 0 16 16"><path d="M8 1.6l5.6 3.2v6.4L8 14.4 2.4 11.2V4.8z"/><path d="M2.4 4.8L8 8l5.6-3.2M8 8v6.4"/></svg>',
    batt: '<svg viewBox="0 0 22 12"><rect x="1" y="1.5" width="17" height="9" rx="2.6" fill="none" stroke="#fff" stroke-opacity=".9" stroke-width="1.1"/><rect x="2.8" y="3.3" width="11.4" height="5.4" rx="1.3" fill="#fff" stroke="none"/><path d="M19.6 4.6v2.8c.7-.2 1.1-.8 1.1-1.4s-.4-1.2-1.1-1.4z" fill="#fff" stroke="none" fill-opacity=".6"/></svg>',
    eye: '<svg viewBox="0 0 16 16"><path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8z"/><circle cx="8" cy="8" r="2"/></svg>',
    eyeOff: '<svg viewBox="0 0 16 16"><path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8z"/><circle cx="8" cy="8" r="2"/><path d="M2.5 2.5l11 11"/></svg>',
    refresh: '<svg viewBox="0 0 16 16"><path d="M13.5 6.5A5.6 5.6 0 0 0 3.2 4.6M2.5 9.5a5.6 5.6 0 0 0 10.3 1.9M3 1.8v3h3M13 14.2v-3h-3"/></svg>',
    undo: '<svg viewBox="0 0 16 16"><path d="M5 3L2 6l3 3"/><path d="M2 6h7.5a4.5 4.5 0 0 1 0 9H6"/></svg>',
    settings: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="2.4"/><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"/></svg>',
    help: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="6.3"/><path d="M6.2 6.2a1.9 1.9 0 1 1 2.6 1.8c-.5.2-.8.6-.8 1.1v.4M8 11.6v.2"/></svg>',
    sparkles: '<svg viewBox="0 0 16 16"><path d="M8 1.8l1.4 3.6 3.6 1.4-3.6 1.4L8 11.8 6.6 8.2 3 6.8l3.6-1.4z"/></svg>',
    info: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="6.3"/><path d="M8 7.2v4M8 4.8v.2"/></svg>',
    quit: '<svg viewBox="0 0 16 16"><path d="M8 1.8v6M4.6 3.8a5.4 5.4 0 1 0 6.8 0"/></svg>',
    boltLine: '<svg viewBox="0 0 16 16"><path d="M9 1.5L3 9h4.5L7 14.5 13 7H8.5z"/></svg>',
    restart: '<svg viewBox="0 0 16 16"><path d="M13.5 8a5.5 5.5 0 1 1-1.6-3.9M13.5 2v3.6H10"/></svg>',
    others: '<svg viewBox="0 0 16 16"><rect x="2" y="5" width="9" height="8" rx="1.5"/><path d="M5 3h8a1 1 0 0 1 1 1v6M9 9h-5"/></svg>',
    nosign: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="6"/><path d="M3.8 3.8l8.4 8.4"/></svg>',
    finder: '<svg viewBox="0 0 16 16"><path d="M2 4.5A1.5 1.5 0 0 1 3.5 3H6l1.5 1.5h5A1.5 1.5 0 0 1 14 6v5.5a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>',
    timer: '<svg viewBox="0 0 16 16"><circle cx="8" cy="9" r="5.3"/><path d="M8 6.2V9l2 1.3M6.2 1.8h3.6"/></svg>',
    windows: '<svg viewBox="0 0 16 16"><rect x="1.5" y="4" width="10" height="9" rx="1.4"/><path d="M4.5 4V3a1 1 0 0 1 1-1H14a1 1 0 0 1 .5.9V10a1 1 0 0 1-1 1h-2"/></svg>',
    chev: '<svg viewBox="0 0 16 16"><path d="M6 3.5L10.5 8 6 12.5"/></svg>',
  };

  const tabIcons = {
    General: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="2.8"/><path d="M10 2v2.4M10 15.6V18M2 10h2.4M15.6 10H18M4.3 4.3l1.7 1.7M14 14l1.7 1.7M4.3 15.7L6 14M14 6l1.7-1.7"/></svg>',
    Automation: '<svg viewBox="0 0 20 20"><circle cx="10" cy="11" r="6.5"/><path d="M10 7.5V11l2.4 1.6M8 2.2h4"/></svg>',
    Advanced: '<svg viewBox="0 0 20 20"><path d="M3 5h9M15 5h2M3 10h3M9 10h8M3 15h7M13 15h4"/><circle cx="13.5" cy="5" r="1.6"/><circle cx="7.5" cy="10" r="1.6"/><circle cx="11.5" cy="15" r="1.6"/></svg>',
    Exclude: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="7"/><path d="M5 5l10 10"/></svg>',
    Shortcuts: '<svg viewBox="0 0 20 20"><path d="M7 7V5.5A2 2 0 1 0 5.5 7.5H7zm0 0h6m-6 0v6m6-6V5.5a2 2 0 1 1 1.5 2H13zm0 0v6m0 0h-6m6 0v1.5a2 2 0 1 0 1.5-2H13zm-6 0v1.5A2 2 0 1 1 5.5 12.5H7z"/></svg>',
    About: '<svg viewBox="0 0 20 20"><path d="M11 2L4 11.5h5L8.5 18 16 8.5h-5z"/></svg>',
  };

  const APPS = [
    { n: 'Books', i: 'books', u: '0%' },
    { n: 'Calendar', i: 'calendar', u: '1%' },
    { n: 'Discord', i: 'discord', u: '5%' },
    { n: 'Google Chrome', i: 'chrome', u: '14%' },
    { n: 'Maps', i: 'maps', u: '2%' },
    { n: 'Messages', i: 'messages', u: '1%' },
    { n: 'Music', i: 'music', u: '2%' },
    { n: 'Notes', i: 'notes', u: '0%' },
    { n: 'Photos', i: 'photos', u: '1%' },
    { n: 'Podcasts', i: 'podcasts', u: '1%' },
    { n: 'Reminders', i: 'reminders', u: '0%' },
    { n: 'Safari', i: 'safari', u: '6%' },
    { n: 'Telegram', i: 'telegram', u: '2%' },
    { n: 'Terminal', i: 'terminal', u: '0%' },
    { n: 'Visual Studio Code', i: 'vscode', u: '8%' },
  ];
  const BACKGROUND = [
    { n: 'Docker Desktop', u: '3%', bg: true },
    { n: 'Dropbox', u: '1%', bg: true },
    { n: 'Google Drive', u: '0%', bg: true },
  ];

  const generic = '<svg class="gen" viewBox="0 0 18 18"><rect x="1" y="1" width="16" height="16" rx="4" fill="#4A494E"/><rect x="1" y="1" width="16" height="16" rx="4" fill="url(#qxg)" opacity=".5"/><path d="M5.5 6.5h7M5.5 9h7M5.5 11.5h4.5" stroke="#C9C8CE" stroke-width="1.3" stroke-linecap="round"/><defs><linearGradient id="qxg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".25"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient></defs></svg>';
  const icon = a => a.i ? `<img src="${A}icons/${a.i}.png" alt="">` : generic;

  function arrow(x, glass) {
    const fill = glass ? 'rgba(62,56,52,.7)' : '#2B2A2D';
    return `<div class="arrow" style="left:${x}px"><svg width="22" height="11" viewBox="0 0 22 11"><path d="M0 11C5 11 8 1.5 11 1.5S17 11 22 11z" fill="${fill}" stroke="rgba(255,255,255,.16)" stroke-width=".5"/></svg></div>`;
  }

  function row(a, o) {
    const sel = o.selected === 'all' ? !o.unselected.includes(a.n) : o.selected.includes(a.n);
    const cls = ['row'];
    if (o.hover === a.n) cls.push('hover');
    if (o.hl === a.n) cls.push('hl');
    const style = o.rowStyle && o.rowStyle[a.n] ? ` style="${o.rowStyle[a.n]}"` : '';
    const pw = o.force ? 'pw force' : (o.hover === a.n ? 'pw on' : 'pw');
    const use = o.usage && o.usage[a.n] ? o.usage[a.n] : a.u;
    const hot = o.hot && o.hot.includes(a.n) ? ' hot' : '';
    return `<div class="${cls.join(' ')}" data-app="${a.n}"${style}><span class="qx-cb${sel ? ' on' : ''}"></span>${icon(a)}<span class="name">${a.n}${a.tag ? `<span class="tag">${a.tag}</span>` : ''}</span><span class="use${hot}">${use}</span><span class="more${o.moreOn === a.n ? ' on' : ''}">${S.more}</span><span class="${pw}">${o.force ? S.bolt : S.power}</span></div>`;
  }

  function popover(o = {}) {
    o = Object.assign({ selected: 'all', unselected: [], apps: APPS, arrowX: 135, footer: 'Quit one, some, or all apps' }, o);
    const list = o.apps.map(a => row(a, o)).join('');
    const count = o.selected === 'all' ? o.apps.length - o.unselected.length : o.selected.length;
    const isAll = o.selected === 'all' && o.unselected.length === 0;
    let title = o.button || (o.force ? (isAll ? 'Force Quit All' : 'Force Quit Selected') : (isAll ? 'Quit All' : 'Quit Selected'));
    const off = o.buttonOff || count === 0;
    const btn = `<div class="quit${off ? ' off' : ''}${o.press ? ' press' : ''}" data-role="quit">${o.force && !off ? S.bolt : ''}${title}</div>`;
    const headCb = isAll ? 'on' : (count > 0 ? 'part' : '');
    return `<div class="qx-pop${o.glass ? ' glass' : ''}">${arrow(o.arrowX, o.glass)}<div class="body"><div style="height:5px"></div>${btn}<div class="search"><span class="qx-cb ${headCb}"></span><div class="field">${S.search}Search</div></div><div class="list">${list}</div><div class="foot"><span>${o.footer}</span><span class="gear${o.gearOn ? ' on' : ''}" data-role="gear">${S.gear}</span></div>${o.overlay || ''}${o.toast ? `<div class="qx-toast">${S.check}${o.toast}</div>` : ''}</div></div>`;
  }

  function confirm(o) {
    const noun = o.count === 1 ? 'App' : 'Apps';
    const title = o.force ? (o.all ? `Force Quit All ${noun}?` : `Force Quit ${o.count} ${noun}?`) : (o.all ? `Quit All ${noun}?` : `Quit ${o.count} ${noun}?`);
    const ok = o.force ? (o.all ? 'Force Quit All' : 'Force Quit') : (o.all ? 'Quit All' : 'Quit');
    return `<div class="qx-scrim"><div class="qx-confirm"><span class="ic">${o.force ? S.warn : S.question}</span><div><b>${title}</b><small>This will close ${o.count} ${o.count === 1 ? 'application.' : 'applications.'}</small></div><div class="btns"><span>Cancel</span><span class="p${o.force ? ' force' : ''}${o.press ? ' press' : ''}" data-role="confirm">${ok}</span></div></div></div>`;
  }

  function menu(items) {
    return `<div class="qx-menu">${items.map(m => {
      if (m === '-') return '<hr>';
      const lead = m.dot ? '<span class="dot"></span>' : (m.icon ? S[m.icon] : '<span style="width:14px"></span>');
      const tail = m.chev ? `<span class="chev">${S.chev}</span>` : (m.k ? `<span class="k">${m.k}</span>` : '');
      return `<div class="mi${m.on ? ' on' : ''}" ${m.id ? `id="${m.id}"` : ''}>${lead}<span>${m.t}</span>${tail}</div>`;
    }).join('')}</div>`;
  }

  function stats(o) {
    return `<div class="qx-stats">${o.cpu != null ? `<span>${S.cpu}${o.cpu}</span>` : ''}${o.mem != null ? `<span>${S.mem}${o.mem}</span>` : ''}${o.gpu != null ? `<span>${S.gpu}${o.gpu}</span>` : ''}${o.bat != null ? `<span>${S.batt.replace('<svg', '<svg style="width:22px;height:12px"')}${o.bat}</span>` : ''}</div>`;
  }

  function rescue(o) {
    const rows = o.targets.map(t => `<div class="r"><span class="qx-cb on"></span>${icon(t)}<span>${t.n}</span><em>${t.v}</em></div>`).join('');
    return `<div class="qx-rescue">${arrow(o.arrowX || 135)}<div class="body"><div class="h">${S.gauge}${o.title}</div><p>${o.detail}</p><div class="qx-card"><div class="sel"><span class="qx-cb on"></span>Deselect All<em>${o.targets.length} apps</em></div>${rows}</div><div class="btns"><span>Cancel</span><span class="p">Quit ${o.targets.length} apps</span></div></div></div>`;
  }

  function note(o) {
    return `<div class="qx-note"><img src="${A}icon.png" alt=""><div style="flex:1;min-width:0"><div class="t"><span>${o.title}</span><small>${o.time || 'now'}</small></div><p>${o.body}</p></div></div>`;
  }

  function settings(o) {
    const tabs = Object.keys(tabIcons).map(t => `<div class="tab${t === o.tab ? ' on' : ''}">${tabIcons[t]}${t}</div>`).join('');
    return `<div class="qx-win qx-settings"><div class="bar"><span class="lights"><i style="background:#FF5F57"></i><i style="background:#FEBC2E"></i><i style="background:#28C840"></i></span><div class="title">${o.tab}</div><div class="tabs">${tabs}</div></div><div class="content">${o.content}</div></div>`;
  }

  const cb = (t, on = true) => `<span class="cbl"><span class="qx-cb${on ? ' on' : ''}"></span>${t}</span>`;
  const radio = (t, on) => `<span class="radio${on ? ' on' : ''}"><i></i>${t}</span>`;
  const help = '<span class="help">?</span>';
  const r = (label, inner, o = {}) => `<div class="r${o.hl ? ' hl' : ''}${o.dim ? ' dim' : ''}"${o.id ? ` id="${o.id}"` : ''}><span class="l">${label}</span>${inner}${o.help === false ? '' : help}</div>`;

  function general(o = {}) {
    return [
      r('Startup:', cb('Open QuitX at login')),
      r('Sounds:', cb('Play cool sounds', o.sounds !== false), { hl: o.hl === 'sounds', id: 'r-sounds' }),
      r('Updates:', cb('Check for updates automatically'), { hl: o.hl === 'updates' }),
      r('', cb('Download and prepare updates automatically'), { hl: o.hl === 'updates' }),
      r('Menu Bar:', cb('Show stats in menu bar', o.stats !== false), { hl: o.hl === 'stats', id: 'r-stats' }),
      r('', `<span class="sub">${cb('CPU', o.stats !== false)}${cb('Memory', o.stats !== false)}${cb('GPU', o.stats !== false)}${cb('Battery', o.stats !== false)}</span>`, { hl: o.hl === 'stats', help: false }),
      r('Appearance:', `<span class="sub" id="appearance">${radio('Classic', o.glass === false)}${radio('Liquid Glass', o.glass !== false)}</span>`, { hl: o.hl === 'theme' }),
      r('Sort:', '<span class="select">A-Z Alphabetical</span>'),
      r('Default:', `<span class="select" id="default-mode">${o.force ? 'Force quit' : 'Normal quit'}</span>`, { hl: o.hl === 'default' }),
    ].join('');
  }

  function automation(o = {}) {
    const sleep = o.sleep !== false;
    return [
      r('Power:', cb('Save power on battery', false)),
      r('Sleep:', cb('Quit apps when Mac sleeps', sleep), { hl: o.hl === 'sleep', id: 'r-sleep' }),
      r('', `<span class="sub"><span class="small">Time format</span>${radio('24-hour', false)}${radio('12-hour', true)}</span>`, { dim: !sleep, help: false, hl: o.hl === 'sleep' }),
      r('', `<span class="sub"><span class="small">From:</span><span class="select">12</span>:<span class="select">00</span><span class="select">AM</span></span>`, { dim: !sleep, help: false, hl: o.hl === 'sleep' }),
      r('', `<span class="sub"><span class="small">To:</span><span class="select">6</span>:<span class="select">00</span><span class="select">AM</span></span>`, { dim: !sleep, help: false, hl: o.hl === 'sleep' }),
      r('Windows:', cb('Quit app when its last window closes', o.lastWindow !== false)),
      r('Health:', cb('Warn &amp; rescue CPU hogs', o.hog !== false), { hl: o.hl === 'health', id: 'r-health' }),
      r('', `<span class="sub" style="gap:6px"><span style="font-size:12px">CPU over</span><span style="font-size:12px">80</span><span class="stepper"></span><span style="font-size:12px">%</span></span>`, { help: false, hl: o.hl === 'health' }),
      r('', cb('Rescue on memory pressure', o.mem !== false), { hl: o.hl === 'health' }),
      r('', `<span class="sub" style="gap:6px"><span style="font-size:12px">Memory over</span><span style="font-size:12px">12</span><span class="stepper"></span><span style="font-size:12px">GB of 16</span></span>`, { help: false, hl: o.hl === 'health' }),
      r('Auto Quit:', cb('Quit inactive apps after', false)),
    ].join('');
  }

  function advanced(o = {}) {
    return [
      r('Background:', cb('View background apps', o.bg !== false), { hl: o.hl === 'bg' }),
      r('', cb('Group background instances'), { hl: o.hl === 'bg' }),
      r('Protection:', cb('Never quit music apps', o.music !== false), { hl: o.hl === 'exclude' }),
      r('Behavior:', cb('Select apps by default')),
      r('', cb('Disable quit tips', false)),
      r('', cb('Confirm single app quit &amp; restart', o.confirm !== false), { hl: o.hl === 'confirm' }),
      r('Extras:', cb('Include Finder Windows in list', false)),
      r('', cb('Include Empty Trash in list', false)),
    ].join('');
  }

  function exclude(o = {}) {
    const list = o.apps || [{ n: 'Music', i: 'music' }, { n: 'Messages', i: 'messages' }, { n: 'Terminal', i: 'terminal' }];
    const trash = '<svg viewBox="0 0 16 16" width="11" height="11" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.6 8.5h5.8l.6-8.5"/></svg>';
    const rows = list.map(a => `<div class="r2${a.hl ? ' new' : ''}"><span class="qx-cb"></span>${icon(a)}<span>${a.n}</span><span class="x">${trash}</span></div>`).join('');
    return `<p class="note">Apps on this list stay out of manual and automatic Quit actions.</p><div class="qx-excl"><div class="sel"><span class="qx-cb"></span>Select All<em>${list.length} excluded</em></div>${rows}</div><div style="display:flex;justify-content:space-between;margin-top:12px"><span class="btn-sm">+&nbsp;&nbsp;Add Apps…</span><span class="btn-sm" style="opacity:.45">Remove</span></div>`;
  }

  window.QX = { S, APPS, BACKGROUND, icon, popover, confirm, menu, stats, rescue, note, settings, general, automation, advanced, exclude };
})();
