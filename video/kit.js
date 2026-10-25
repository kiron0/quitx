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
    trash: '<svg viewBox="0 0 16 16"><path d="M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.6 8.5h5.8l.6-8.5"/></svg>',
    alarm: '<svg viewBox="0 0 16 16"><circle cx="8" cy="9" r="5"/><path d="M8 6.5V9l1.6 1M2.5 4l2-1.8M13.5 4l-2-1.8"/></svg>',
    network: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="6.2"/><path d="M1.8 8h12.4M8 1.8c1.8 1.9 2.6 3.9 2.6 6.2S9.8 12.3 8 14.2M8 1.8C6.2 3.7 5.4 5.7 5.4 8s.8 4.3 2.6 6.2"/></svg>',
    grid: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2.2" y="2.2" width="4.6" height="4.6" rx="1"/><rect x="9.2" y="2.2" width="4.6" height="4.6" rx="1"/><rect x="2.2" y="9.2" width="4.6" height="4.6" rx="1"/><rect x="9.2" y="9.2" width="4.6" height="4.6" rx="1"/></svg>',
    sliders: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M2 4h7M12 4h2M2 8h2M7 8h7M2 12h5M10 12h4"/><circle cx="10.5" cy="4" r="1.5"/><circle cx="5.5" cy="8" r="1.5"/><circle cx="8.5" cy="12" r="1.5"/></svg>',
    trace: '<svg viewBox="0 0 16 16"><circle cx="4" cy="3.5" r="1.6"/><circle cx="4" cy="12.5" r="1.6"/><circle cx="12" cy="8" r="1.6"/><path d="M4 5.1v5.8M5.4 4.3l5.2 2.9"/></svg>',
    folder: '<svg viewBox="0 0 16 16"><path d="M2 4.5A1.5 1.5 0 0 1 3.5 3H6l1.5 1.5h5A1.5 1.5 0 0 1 14 6v5.5a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>',
    copy: '<svg viewBox="0 0 16 16"><rect x="5" y="5" width="8.5" height="8.5" rx="1.6"/><path d="M11 5V3.6A1.1 1.1 0 0 0 9.9 2.5H3.6a1.1 1.1 0 0 0-1.1 1.1v6.3A1.1 1.1 0 0 0 3.6 11H5"/></svg>',
  };

  const tabIcons = {
    General: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="2.8"/><path d="M10 2v2.4M10 15.6V18M2 10h2.4M15.6 10H18M4.3 4.3l1.7 1.7M14 14l1.7 1.7M4.3 15.7L6 14M14 6l1.7-1.7"/></svg>',
    Automation: '<svg viewBox="0 0 20 20"><circle cx="10" cy="11" r="6.5"/><path d="M10 7.5V11l2.4 1.6M8 2.2h4"/></svg>',
    Advanced: '<svg viewBox="0 0 20 20"><path d="M3 5h9M15 5h2M3 10h3M9 10h8M3 15h7M13 15h4"/><circle cx="13.5" cy="5" r="1.6"/><circle cx="7.5" cy="10" r="1.6"/><circle cx="11.5" cy="15" r="1.6"/></svg>',
    Ports: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="7.5"/><path d="M2.5 10h15M10 2.5c2.2 2.3 3.2 4.8 3.2 7.5s-1 5.2-3.2 7.5M10 2.5C7.8 4.8 6.8 7.3 6.8 10s1 5.2 3.2 7.5"/></svg>',
    Exclude: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="7"/><path d="M5 5l10 10"/></svg>',
    Shortcuts: '<svg viewBox="0 0 20 20"><path d="M7 7V5.5A2 2 0 1 0 5.5 7.5H7zm0 0h6m-6 0v6m6-6V5.5a2 2 0 1 1 1.5 2H13zm0 0v6m0 0h-6m6 0v1.5a2 2 0 1 0 1.5-2H13zm-6 0v1.5A2 2 0 1 1 5.5 12.5H7z"/></svg>',
    About: '<svg viewBox="0 0 20 20"><path d="M11 2L4 11.5h5L8.5 18 16 8.5h-5z"/></svg>',
  };

  const APPS = [
    { n: 'Books', i: 'books', u: '0.0%' },
    { n: 'Calendar', i: 'calendar', u: '1.0%' },
    { n: 'Discord', i: 'discord', u: '5.0%' },
    { n: 'Google Chrome', i: 'chrome', u: '14.0%' },
    { n: 'Maps', i: 'maps', u: '2.0%' },
    { n: 'Messages', i: 'messages', u: '1.0%' },
    { n: 'Music', i: 'music', u: '2.0%' },
    { n: 'Notes', i: 'notes', u: '0.0%' },
    { n: 'Photos', i: 'photos', u: '1.0%' },
    { n: 'Podcasts', i: 'podcasts', u: '1.0%' },
    { n: 'Reminders', i: 'reminders', u: '0.0%' },
    { n: 'Safari', i: 'safari', u: '6.0%' },
    { n: 'Telegram', i: 'telegram', u: '2.0%' },
    { n: 'Terminal', i: 'terminal', u: '0.0%' },
    { n: 'Visual Studio Code', i: 'vscode', u: '8.0%' },
  ];
  const BACKGROUND = [
    { n: 'Docker Desktop', u: '3.0%', bg: true },
    { n: 'Dropbox', u: '1.0%', bg: true },
    { n: 'Google Drive', u: '0.0%', bg: true },
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
    o = Object.assign({ selected: 'all', unselected: [], apps: APPS, arrowX: 165, footer: 'Quit one, some, or all apps' }, o);
    const list = o.apps.map(a => row(a, o)).join('');
    const count = o.selected === 'all' ? o.apps.length - o.unselected.length : o.selected.length;
    const isAll = o.selected === 'all' && o.unselected.length === 0;
    let title = o.button || (o.force ? (isAll ? 'Force Quit All' : 'Force Quit Selected') : (isAll ? 'Quit All' : 'Quit Selected'));
    const off = o.buttonOff || count === 0;
    const btn = `<div class="quit${off ? ' off' : ''}${o.press ? ' press' : ''}" data-role="quit">${o.force && !off ? S.bolt : ''}${title}</div>`;
    const headCb = isAll ? 'on' : (count > 0 ? 'part' : '');
    return `<div class="qx-pop${o.glass ? ' glass' : ''}${o.tabs ? ' wide' : ''}">${arrow(o.arrowX, o.glass)}<div class="body"><div style="height:5px"></div>${o.tabs ? tabbar('apps') : ''}${btn}<div class="search"><span class="qx-cb ${headCb}"></span><div class="field">${S.search}Search</div></div><div class="list">${list}</div><div class="foot"><span>${o.footer}</span><span class="gear${o.gearOn ? ' on' : ''}" data-role="gear">${S.sliders}</span></div>${o.overlay || ''}${o.toast ? `<div class="qx-toast">${S.check}${o.toast}</div>` : ''}</div></div>`;
  }

  function tabbar(active) {
    return `<div class="tabbar"><span class="${active === 'apps' ? 'on' : ''}" data-tab="apps">${S.grid}Apps</span><span class="${active === 'ports' ? 'on' : ''}" data-tab="ports">${S.network}Ports</span></div>`;
  }

  const PORTS = [
    { p: 3000, n: 'node', i: 'vscode', exp: 'Local', mem: '174 MB' },
    { p: 5173, n: 'vite', i: 'vscode', exp: 'Local', mem: '92 MB' },
    { p: 5432, n: 'postgres', exp: 'Local', mem: '38 MB' },
    { p: 6379, n: 'redis-server', exp: 'Local', mem: '11 MB' },
    { p: 8000, n: 'python3', i: 'terminal', exp: 'Public', mem: '64 MB' },
    { p: 8080, n: 'api', docker: true, exp: 'Public', mem: '' },
  ];

  function portRow(x, o) {
    const sel = o.selected === 'all' ? !o.unselected.includes(x.p) : o.selected.includes(x.p);
    const cls = ['row', 'prow'];
    if (o.hover === x.p) cls.push('hover');
    if (o.hl === x.p) cls.push('hl');
    const style = o.rowStyle && o.rowStyle[x.p] ? ` style="${o.rowStyle[x.p]}"` : '';
    const pw = o.force ? 'pw force' : (o.hover === x.p ? 'pw on' : 'pw');
    const badges = `${x.docker ? '<span class="badge docker">docker</span>' : ''}<span class="badge ${x.exp === 'Public' ? 'pub' : 'loc'}">${x.exp}</span>`;
    return `<div class="${cls.join(' ')}" data-port="${x.p}"${style}><span class="qx-cb${sel ? ' on' : ''}"></span>${icon(x)}<span class="pnum">:${x.p}</span><span class="name">${x.n}${badges}</span><span class="use">${x.mem}</span><span class="more${o.moreOn === x.p ? ' on' : ''}">${S.more}</span><span class="${pw}">${o.force ? S.bolt : S.power}</span></div>`;
  }

  function ports(o = {}) {
    o = Object.assign({ selected: [], unselected: [], ports: PORTS, arrowX: 165, footer: 'Free up occupied ports 🧹' }, o);
    const list = o.ports.map(x => portRow(x, o)).join('');
    const count = o.selected === 'all' ? o.ports.length - o.unselected.length : o.selected.length;
    const isAll = o.selected === 'all' && o.unselected.length === 0;
    const noun = count === 1 ? 'Port' : 'Ports';
    const title = o.force ? (isAll ? 'Force Kill All Ports' : (count ? `Force Kill ${count} ${noun}` : 'Force Kill Selected Ports')) : (isAll ? 'Kill All Ports' : (count ? `Kill ${count} ${noun}` : 'Kill Selected Ports'));
    const btn = `<div class="quit${count === 0 ? ' off' : ''}" data-role="quit">${o.force && count ? S.bolt : ''}${title}</div>`;
    const headCb = isAll ? 'on' : (count > 0 ? 'part' : '');
    return `<div class="qx-pop wide${o.glass ? ' glass' : ''}">${arrow(o.arrowX, o.glass)}<div class="body"><div style="height:5px"></div>${tabbar('ports')}${btn}<div class="search"><span class="qx-cb ${headCb}"></span><div class="field">${S.search}Search ports, apps, folders</div></div><div class="list">${list}</div><div class="foot"><span>${o.footer}</span><span class="gear${o.gearOn ? ' on' : ''}" data-role="gear">${S.sliders}</span></div>${o.overlay || ''}${o.toast ? `<div class="qx-toast">${S.check}${o.toast}</div>` : ''}</div></div>`;
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
    return `<div class="qx-stats">${o.ports != null ? `<span class="pc">${S.network}${o.ports}</span>` : ''}${o.cpu != null ? `<span>${S.cpu}${o.cpu}</span>` : ''}${o.mem != null ? `<span>${S.mem}${o.mem}</span>` : ''}${o.gpu != null ? `<span>${S.gpu}${o.gpu}</span>` : ''}${o.bat != null ? `<span>${S.batt.replace('<svg', '<svg style="width:22px;height:12px"')}${o.bat}</span>` : ''}</div>`;
  }

  function rescue(o) {
    const rows = o.targets.map(t => `<div class="r"><span class="qx-cb on"></span>${icon(t)}<span>${t.n}</span><em>${t.v}</em></div>`).join('');
    return `<div class="qx-rescue">${arrow(o.arrowX || 135)}<div class="body"><div class="h">${S.gauge}${o.title}</div><p>${o.detail}</p><div class="qx-card"><div class="sel"><span class="qx-cb on"></span>Deselect All<em>${o.targets.length} apps</em></div>${rows}</div><div class="btns"><span>Cancel</span><span class="p">Quit ${o.targets.length} apps</span></div></div></div>`;
  }

  function note(o) {
    return `<div class="qx-note"><img src="${A}icon.png" alt=""><div style="flex:1;min-width:0"><div class="t"><span>${o.title}</span><small>${o.time || 'now'}</small></div><p>${o.body}</p></div></div>`;
  }

  const sideIcons = Object.assign({
    Overview: '<svg viewBox="0 0 20 20"><rect x="3" y="3" width="5.5" height="5.5" rx="1.2"/><rect x="11.5" y="3" width="5.5" height="5.5" rx="1.2"/><rect x="3" y="11.5" width="5.5" height="5.5" rx="1.2"/><rect x="11.5" y="11.5" width="5.5" height="5.5" rx="1.2"/></svg>',
    Marquee: '<svg viewBox="0 0 512 512" class="mq"><rect x="16" y="16" width="480" height="480" rx="116" fill="#FFCF1A"/><g fill="none" stroke="#1D1D1F" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"><path d="M112 196V128a16 16 0 0 1 16-16h68"/><path d="M400 316v68a16 16 0 0 1-16 16h-68"/></g><rect x="166" y="166" width="124" height="124" rx="20" fill="none" stroke="#1D1D1F" stroke-width="26"/><rect x="222" y="222" width="124" height="124" rx="20" fill="#1D1D1F"/></svg>',
  }, tabIcons);
  const sideGroups = [['', ['Overview']], ['App', ['General', 'Shortcuts']], ['Quitting', ['Automation', 'Advanced', 'Exclude']], ['Developer', ['Ports']], ['QuitX', ['About']], ['More Apps', ['Marquee']]];
  const summaries = {
    General: 'Startup, sounds, updates, menu bar stats and how QuitX looks.',
    Automation: 'Let QuitX quit apps on sleep, after their last window, or when idle.',
    Advanced: 'Background apps, music protection, confirmations and extras.',
    Exclude: 'Apps and ports QuitX never quits, manually or automatically.',
    Ports: 'Find and free ports held by dev servers, databases and Docker.',
    Shortcuts: 'Open QuitX or quit apps from anywhere with your own key combos.',
    About: 'Version, updates and ways to get in touch.',
  };

  function settings(o) {
    const side = sideGroups.map(([g, tabs]) => `${g ? `<div class="sg">${g}</div>` : ''}${tabs.map(t => `<div class="si${t === o.tab ? ' on' : ''}" data-tab="${t}">${sideIcons[t]}<span>${t}</span></div>`).join('')}`).join('');
    return `<div class="qx-win qx-settings side"><div class="sb"><span class="lights"><i style="background:#FF5F57"></i><i style="background:#FEBC2E"></i><i style="background:#58565A"></i></span><div class="ss">${S.search}Search settings…</div><div class="sl">${side}</div></div><div class="dt"><div class="dh"><div class="h">${o.tab}</div><div class="sum">${summaries[o.tab] || ''}</div></div><div class="pv"><div class="pane"${o.scroll ? ` style="transform:translateY(-${o.scroll}px)"` : ''}>${o.content}</div></div></div></div>`;
  }

  const cb = (t, on = true) => `<span class="cbl"><span class="qx-sw${on ? ' on' : ''}"></span>${t}</span>`;
  const help = '<span class="help">?</span>';
  const T = {
    gauge: '<svg viewBox="0 0 16 16"><path d="M2.4 11.6a6 6 0 1 1 11.2 0"/><path d="M8 9l2.6-2.6"/></svg>',
    text: '<svg viewBox="0 0 22 16"><text x="11" y="12.5" text-anchor="middle" font-size="12" font-family="Inter" font-weight="500" fill="currentColor" stroke="none">Aa</text></svg>',
    abc: '<svg viewBox="0 0 26 16"><text x="13" y="12.5" text-anchor="middle" font-size="11.5" font-family="Inter" font-weight="500" fill="currentColor" stroke="none">Abc</text></svg>',
    pct: '<svg viewBox="0 0 16 16"><path d="M12.5 3.5l-9 9"/><circle cx="4.5" cy="4.5" r="1.6"/><circle cx="11.5" cy="11.5" r="1.6"/></svg>',
    mem: '<svg viewBox="0 0 16 16"><rect x="2" y="5" width="12" height="6" rx="1.2"/><path d="M4.5 11v1.8M7 11v1.8M9.5 11v1.8M12 11v1.8"/></svg>',
    fast: '<svg viewBox="0 0 16 16"><path d="M9 1.5L3 9h4.5L7 14.5 13 7H8.5z"/></svg>',
    slow: '<svg viewBox="0 0 16 16"><path d="M2.5 11h11M4 11c0-3 1.8-5 4-5s4 2 4 5"/><circle cx="13" cy="8" r="1.3"/></svg>',
    clock: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="5.6"/><path d="M8 4.8V8l2 1.3"/></svg>',
    clock12: '<svg viewBox="0 0 16 16"><path d="M13.4 7a5.6 5.6 0 1 1-4-4.4"/><path d="M8 4.8V8l2 1.3"/><circle cx="12.4" cy="3.6" r="1.3" fill="currentColor"/></svg>',
    square: '<svg viewBox="0 0 16 16"><rect x="3" y="4" width="10" height="8" rx="1.6" fill="currentColor"/></svg>',
    drop: '<svg viewBox="0 0 16 16"><path d="M8 2.2c2.4 3 3.8 5.1 3.8 7a3.8 3.8 0 0 1-7.6 0c0-1.9 1.4-4 3.8-7z" fill="currentColor"/></svg>',
    down: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="5.6"/><path d="M6 6l4 4M10 6.6V10H6.6"/></svg>',
    up: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="5.6"/><path d="M6 10l4-4M6.6 6H10v3.4"/></svg>',
    arrowUp: '<svg viewBox="0 0 16 16"><path d="M8 13V3M4 7l4-4 4 4"/></svg>',
    arrowDown: '<svg viewBox="0 0 16 16"><path d="M8 3v10M4 9l4 4 4-4"/></svg>',
    list: '<svg viewBox="0 0 16 16"><path d="M6 4h7.5M6 8h7.5M6 12h7.5"/><circle cx="3" cy="4" r=".6" fill="currentColor"/><circle cx="3" cy="8" r=".6" fill="currentColor"/><circle cx="3" cy="12" r=".6" fill="currentColor"/></svg>',
    folder: '<svg viewBox="0 0 16 16"><path d="M2 4.5A1.5 1.5 0 0 1 3.5 3H6l1.5 1.5h5A1.5 1.5 0 0 1 14 6v5.5a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>',
    docker: '<svg viewBox="0 0 16 16"><path d="M1.8 8.5h11.4c.6 0 1-.6 1.6-.8-.3 2.9-2.6 5-6.3 5-3.2 0-5.6-1.6-6.7-4.2z"/><path d="M3.5 8.5V6.5h2v2M5.5 8.5V6.5h2v2M7.5 8.5V6.5h2v2M5.5 6.5v-2h2v2"/></svg>',
    branch: '<svg viewBox="0 0 16 16"><path d="M4 2.5v3.2c0 1.6 1.4 2.8 4 3.3 2.6-.5 4-1.7 4-3.3V2.5M8 9v4.5"/></svg>',
  };
  const tiles = (items, o = {}) => `<span class="tiles${o.small ? ' sm' : ''}"${o.id ? ` id="${o.id}"` : ''}>${items.map(x => `<span class="tile${x.on ? ' on' : ''}">${x.i}<b>${x.t}</b></span>`).join('')}</span>`;
  const sub = (label, inner, cls = '') => `<span class="sub${cls ? ' ' + cls : ''}"><span class="small">${label}</span>${inner}</span>`;
  const tstep = v => `<span class="tstep">${v}<i></i></span>`;
  const sectionSymbols = {
    Startup: S.power,
    Sounds: '<svg viewBox="0 0 16 16"><path d="M3 6.2h2.4L8.5 3.5v9L5.4 9.8H3z"/><path d="M10.6 6a2.6 2.6 0 0 1 0 4M12.4 4.4a5 5 0 0 1 0 7.2"/></svg>',
    Updates: S.refresh,
    'Menu Bar': '<svg viewBox="0 0 16 16"><rect x="2" y="3.5" width="12" height="9" rx="1.8"/><path d="M2 6.3h12"/></svg>',
    Refresh: S.refresh,
    Appearance: '<svg viewBox="0 0 16 16"><path d="M8 2.2a5.8 5.8 0 1 0 0 11.6c1 0 1.2-.8.8-1.5-.5-.9 0-1.9 1.1-1.9h1.6a2.3 2.3 0 0 0 2.3-2.3C13.8 4.6 11.2 2.2 8 2.2z"/><circle cx="5.2" cy="7" r=".8"/><circle cx="7.6" cy="4.9" r=".8"/><circle cx="10.4" cy="5.6" r=".8"/></svg>',
    Sort: '<svg viewBox="0 0 16 16"><path d="M5 13V3M2.5 5.5L5 3l2.5 2.5M11 3v10M8.5 10.5L11 13l2.5-2.5"/></svg>',
    Default: '<svg viewBox="0 0 16 16"><path d="M8 4.2a3.8 3.8 0 0 0-2.6 6.6M8 2a6 6 0 0 0-4.3 10.2M8 6.4a1.6 1.6 0 0 0-1.6 1.6v1.2l3.4 4.6"/></svg>',
    Reset: '<svg viewBox="0 0 16 16"><path d="M3.2 6.2A5 5 0 1 1 3 9.5M3 3v3.4h3.4"/></svg>',
    Sleep: '<svg viewBox="0 0 16 16"><path d="M10.5 10.8A5.2 5.2 0 0 1 5.2 3.4a5.2 5.2 0 1 0 7.2 6.8 5 5 0 0 1-1.9.6z"/><path d="M10 2.5h2l-2 2.2h2"/></svg>',
    Windows: '<svg viewBox="0 0 16 16"><rect x="2" y="3.5" width="12" height="9" rx="1.8"/><path d="M4.5 5.6h.1M6.3 5.6h.1"/></svg>',
    Health: '<svg viewBox="0 0 16 16"><rect x="3" y="2.5" width="10" height="11" rx="1.8"/><path d="M5.5 5.5h2M5.5 8h5M5.5 10.5h5"/></svg>',
    'Auto Quit': '<svg viewBox="0 0 16 16"><path d="M4.5 2.5h7M4.5 13.5h7M5.5 2.5c0 3 5 3 5 5.5s-5 2.5-5 5.5M10.5 2.5c0 3-5 3-5 5.5s5 2.5 5 5.5"/></svg>',
    'Port Killing': S.network,
    Discovery: '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="1.4"/><path d="M5.2 5.2a4 4 0 0 0 0 5.6M10.8 5.2a4 4 0 0 1 0 5.6M3.4 3.4a6.5 6.5 0 0 0 0 9.2M12.6 3.4a6.5 6.5 0 0 1 0 9.2"/></svg>',
    'Group By': '<svg viewBox="0 0 16 16"><path d="M8 2.5l5.5 3L8 8.5l-5.5-3z"/><path d="M2.5 8.2L8 11.2l5.5-3M2.5 10.8L8 13.8l5.5-3"/></svg>',
    Safety: '<svg viewBox="0 0 16 16"><path d="M8 1.8l5 2v4c0 3-2.2 5.3-5 6.4-2.8-1.1-5-3.4-5-6.4v-4z"/><path d="M5.8 8.2l1.6 1.6 3-3.2"/></svg>',
    Selection: '<svg viewBox="0 0 16 16"><circle cx="4" cy="5" r="1.4"/><circle cx="4" cy="11" r="1.4"/><path d="M7.5 5h6M7.5 11h6"/></svg>',
    Exclude: S.nosign,
  };
  const section = (label, dim) => {
    const title = label.replace(/:$/, '');
    return `<div class="sec${dim ? ' dim' : ''}"><span class="sec-icon">${sectionSymbols[title] || S.sliders}</span><b>${title}</b><i></i></div>`;
  };
  const r = (label, inner, o = {}) => `${label ? section(label, o.dim) : ''}<div class="r${o.hl ? ' hl' : ''}${o.dim ? ' dim' : ''}"${o.id ? ` id="${o.id}"` : ''}>${inner}${o.help === false ? '' : help}</div>`;

  function general(o = {}) {
    const st = o.stats !== false;
    return [
      r('Startup:', cb('Open QuitX at login')),
      r('Sounds:', cb('Play cool sounds', o.sounds !== false), { hl: o.hl === 'sounds', id: 'r-sounds' }),
      r('Updates:', cb('Check for updates automatically'), { hl: o.hl === 'updates' }),
      r('', cb('Download and prepare updates automatically'), { hl: o.hl === 'updates' }),
      r('Menu Bar:', cb('Show stats in menu bar', st), { hl: o.hl === 'stats', id: 'r-stats' }),
      r('', `<span class="sub">${cb('CPU', st)}${cb('Memory', st)}${cb('GPU', st)}${cb('Battery', st)}</span>`, { hl: o.hl === 'stats', dim: !st }),
      r('', sub('Style format', tiles([{ t: 'Icon', i: T.gauge, on: true }, { t: 'Text', i: T.text }])), { help: false, dim: !st }),
      r('', sub('Refresh', tiles([{ t: '1 sec', i: T.fast, on: true }, { t: '2 sec', i: T.gauge }, { t: '3 sec', i: T.gauge }, { t: '5 sec', i: T.gauge }, { t: '10 sec', i: T.slow }], { small: true })), { hl: o.hl === 'stats' || o.hl === 'refresh', dim: !st }),
      r('Appearance:', tiles([{ t: 'Classic', i: T.square, on: o.glass === false }, { t: 'Liquid Glass', i: T.drop, on: o.glass !== false }], { id: 'appearance' }), { hl: o.hl === 'theme' }),
      r('Sort:', tiles([{ t: 'CPU High', i: T.down }, { t: 'CPU Low', i: T.up }, { t: 'Memory High', i: T.down }, { t: 'Memory Low', i: T.up }, { t: 'A–Z', i: T.abc, on: true }, { t: 'Z–A', i: T.abc }], { small: true })),
      r('Default:', tiles([{ t: 'Normal Quit', i: S.power, on: !o.force }, { t: 'Force Quit', i: T.fast, on: !!o.force }], { id: 'default-mode' }), { hl: o.hl === 'default' }),
    ].join('');
  }

  function automation(o = {}) {
    const sleep = o.sleep !== false;
    const step = '<span class="stepper"></span>';
    return [
      r('Sleep:', cb('Quit apps when Mac sleeps', sleep), { hl: o.hl === 'sleep', id: 'r-sleep' }),
      r('', sub('Time format', tiles([{ t: '24-hour', i: T.clock }, { t: '12-hour', i: T.clock12, on: true }])), { dim: !sleep, help: false, hl: o.hl === 'sleep' }),
      r('', sub('From:', `${tstep('12')}<span class="colon">:</span>${tstep('00')}${tstep('AM')}`, 'time'), { dim: !sleep, help: false, hl: o.hl === 'sleep' }),
      r('', sub('To:', `${tstep('6')}<span class="colon">:</span>${tstep('00')}${tstep('AM')}`, 'time'), { dim: !sleep, help: false, hl: o.hl === 'sleep' }),
      r('Windows:', cb('Quit app when its last window closes', o.lastWindow !== false)),
      r('Health:', cb('Warn &amp; rescue CPU hogs', o.hog !== false), { hl: o.hl === 'health', id: 'r-health' }),
      r('', `<span class="sub" style="gap:7px"><span class="small" style="width:auto">CPU over</span><span class="num">80</span>${step}<span class="num">%</span></span>`, { help: false, hl: o.hl === 'health' }),
      r('', cb('Rescue on memory pressure', o.mem !== false), { hl: o.hl === 'health' }),
      r('', `<span class="sub" style="gap:7px"><span class="small" style="width:auto">Memory over</span><span class="num">12</span>${step}<span class="num">GB of 16</span></span>`, { help: false, hl: o.hl === 'health' }),
      r('Auto Quit:', cb('Quit inactive apps after', false)),
    ].join('');
  }

  function portSettings(o = {}) {
    const on = o.enabled !== false;
    const d = { dim: !on };
    return [
      r('Port Killing:', cb('Enable port killing', on), { hl: o.hl === 'enable' }),
      r('Refresh:', tiles([{ t: '1 sec', i: T.fast }, { t: '2 sec', i: T.gauge }, { t: '3 sec', i: T.gauge, on: true }, { t: '5 sec', i: T.gauge }, { t: '10 sec', i: T.slow }], { small: true }), d),
      r('Discovery:', cb('Include UDP listeners', false), d),
      r('Menu Bar:', cb('Show listening port count', o.count !== false), { dim: !on, hl: o.hl === 'count' }),
      r('Group By:', tiles([{ t: 'None', i: T.list, on: true }, { t: 'Project', i: T.folder }, { t: 'Docker', i: T.docker }, { t: 'Process', i: T.branch }], { small: true }), d),
      r('Sort:', tiles([{ t: 'Port Low', i: T.arrowUp, on: true }, { t: 'Port High', i: T.arrowDown }, { t: 'Name', i: T.abc }, { t: 'Memory', i: T.mem }, { t: 'CPU', i: S.cpu }], { small: true }), d),
      r('Default:', tiles([{ t: 'Kill', i: S.power, on: true }, { t: 'Force Kill', i: T.fast }], { small: true }), d),
      r('Safety:', cb('Confirm before killing ports'), { dim: !on, hl: o.hl === 'safety' }),
      r('Selection:', cb('Select all ports by default', false), d),
      r('Exclude:', `<span class="btn-sm">${S.nosign.replace('<svg', '<svg style="width:13px;height:13px;margin-right:7px;fill:none;stroke:currentColor;stroke-width:1.5"')}Manage Excluded Ports…</span>`, d),
    ].join('');
  }

  function overview(o = {}) {
    return `<div class="qx-overview">
      <div class="hero-greet">
        <h3>Welcome to QuitX</h3>
        <p>All features, vitals, and quick toggles in one clean view.</p>
      </div>
      <div class="stat-row">
        <div class="stat-tile"><div class="lbl">Smart Rescue</div><div class="val"><span>Active</span><span class="pill green">On</span></div></div>
        <div class="stat-tile"><div class="lbl">Listening Ports</div><div class="val"><span>6 Ports</span><span class="pill teal">Live</span></div></div>
        <div class="stat-tile"><div class="lbl">Menu Bar Stats</div><div class="val"><span>CPU &amp; Mem</span><span class="pill gold">4 Items</span></div></div>
      </div>
      <div class="grid">
        <div class="card"><div class="card-icon" style="background:rgba(40,199,180,.15);color:#28C7B4">${S.network}</div><div class="card-info"><b>Port Killing</b><span>Free occupied ports held by Node, Vite, Docker and Postgres.</span></div></div>
        <div class="card"><div class="card-icon" style="background:rgba(255,159,10,.15);color:#FF9F0A">${T.clock}</div><div class="card-info"><b>Quit on Sleep</b><span>Close open apps when your Mac sleeps, between hours you pick.</span></div></div>
        <div class="card"><div class="card-icon" style="background:rgba(10,132,255,.15);color:#0A84FF">${S.cpu}</div><div class="card-info"><b>Menu Bar Stats</b><span>Real-time CPU, memory, GPU and battery vitals in your menu bar.</span></div></div>
        <div class="card"><div class="card-icon" style="background:rgba(191,90,242,.15);color:#BF5AF2">${S.windows}</div><div class="card-info"><b>Last Window Quit</b><span>Quit applications automatically when their last window closes.</span></div></div>
      </div>
    </div>`;
  }

  function aboutTab(o = {}) {
    return `<div class="qx-about">
      <div class="hero">
        <img src="${A}icon.png" alt="">
        <div class="hero-text">
          <h2>QuitX <span class="ver">VERSION 1.2.1</span></h2>
          <div class="tagline">Quit everything. Keep what matters.</div>
          <div class="status"><svg width="12" height="12" viewBox="0 0 12 12"><circle cx="6" cy="6" r="6" fill="#30D158"/><path d="M3.2 6.2l2 2 3.8-4" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg> Up to date</div>
        </div>
        <span class="hero-btn">Check for Updates</span>
      </div>
      <div class="sec"><span class="sec-icon">${S.sparkles}</span><b>Why QuitX</b><i></i></div>
      <div class="highlights">
        <div class="hi-card"><div class="hi-icon"><svg viewBox="0 0 16 16" fill="currentColor"><path d="M12.8 1.6C9.6 4.8 8.8 8 8.8 8s-2.4-2.4-5.6-2.4C1.6 8 2.4 12 4.8 14.4c1.6 1.6 4 1.6 5.6 0 2.4-2.4 4-5.6 2.4-12.8z"/></svg></div><div><b>Native</b><span>Fast SwiftUI app with a small footprint.</span></div></div>
        <div class="hi-card"><div class="hi-icon"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M8 1.8l5 2v4c0 3-2.2 5.3-5 6.4-2.8-1.1-5-3.4-5-6.4v-4z"/><path d="M6 7.8l1.6 1.6 3-3"/></svg></div><div><b>Private</b><span>No account, tracking or analytics.</span></div></div>
        <div class="hi-card"><div class="hi-icon"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M5 4.5L1.5 8 5 11.5M11 4.5l3.5 3.5L11 11.5M9.5 2.5l-3 11"/></svg></div><div><b>Open Source</b><span>Free forever under the MIT license.</span></div></div>
      </div>
      <div class="sec"><span class="sec-icon">${S.help}</span><b>Resources</b><i></i></div>
      <div class="resources">
        <div class="res-card"><div class="ricon" style="background:rgba(10,132,255,.15);color:#0A84FF"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="6.3"/><path d="M6.2 6.2a1.9 1.9 0 1 1 2.6 1.8c-.5.2-.8.6-.8 1.1v.4M8 11.6v.2"/></svg></div><b>Help Center</b><p>Guides for every feature.</p><span class="link">Open Help &rarr;</span></div>
        <div class="res-card"><div class="ricon" style="background:rgba(191,90,242,.15);color:#BF5AF2"><svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.8l1.4 3.6 3.6 1.4-3.6 1.4L8 11.8 6.6 8.2 3 6.8l3.6-1.4z"/></svg></div><b>What’s New</b><p>Recent features and fixes.</p><span class="link">View Updates &rarr;</span></div>
        <div class="res-card"><div class="ricon" style="background:rgba(255,69,58,.15);color:#FF453A">${S.warn}</div><b>Report an Issue</b><p>Share feedback or a bug.</p><span class="link">Open GitHub &rarr;</span></div>
      </div>
    </div>`;
  }

  function statsDetail(o = {}) {
    const cpus = [14, 28, 42, 18, 55, 32, 22, 10];
    return `<div class="qx-stats-panel">${arrow(o.arrowX || 155)}
      <div class="sd-sec">
        <div class="sd-head"><div class="sd-title">${S.cpu}System CPU</div><div class="sd-val">12%</div></div>
        <div class="sd-bar"><div class="sd-seg-user" style="width:8%"></div><div class="sd-seg-sys" style="width:4%"></div></div>
        <div class="sd-legend"><span>User 8%</span><span>System 4%</span><span>Idle 88%</span></div>
        <div class="sd-cores">${cpus.map(h => `<div class="sd-core" style="height:${h}%"></div>`).join('')}</div>
      </div>
      <div class="sd-sec" style="margin-bottom:0">
        <div class="sd-head"><div class="sd-title">${S.mem}Used Memory</div><div class="sd-val">9.4 GB <small style="font-size:11px;font-weight:400;color:var(--qx-sub)">/ 16 GB</small></div></div>
        <div class="sd-bar"><div class="sd-seg-app" style="width:38%"></div><div class="sd-seg-wire" style="width:13%"></div><div class="sd-seg-comp" style="width:8%"></div></div>
        <div class="sd-legend"><span>App 6.1 GB</span><span>Wired 2.1 GB</span><span>Compressed 1.2 GB</span></div>
      </div>
    </div>`;
  }

  window.QX = { S, APPS, BACKGROUND, PORTS, icon, popover, ports, confirm, menu, stats, rescue, note, settings, general, automation, portSettings, overview, aboutTab, statsDetail };
})();
