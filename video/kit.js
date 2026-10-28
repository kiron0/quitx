(() => {
  const A = window.QX_ASSETS || '../site/assets/';

  const S = {
    power: '<svg class="[.qx-pop_.row_.pw_&]:w-[11px] [.qx-pop_.row_.pw_&]:h-[11px] [.qx-settings_.tile_&]:py-[4px] [.qx-settings_.tile_&]:px-0 [.qx-settings_.tile_&]:w-full [.qx-settings_.tile_&]:h-[22px] [.qx-settings_.tile_&]:fill-none [.qx-settings_.tile_&]:stroke-current [.qx-settings_.tile_&]:stroke-[1.4] [.qx-settings_.tile_&]:[stroke-linecap:round] [.qx-settings_.tile_&]:[stroke-linejoin:round] [.qx-settings_.tile_&]:[box-sizing:border-box] [.qx-settings_.tile_&]:rounded-[5px] [.qx-settings_.tile.on_&]:bg-transparent [.qx-settings_.tile.on_&]:bg-[linear-gradient(135deg,rgba(254,188,51,.22),rgba(254,188,51,.06))] [.qx-settings_.tiles.sm_.tile_&]:py-[1px] [.qx-settings_.tiles.sm_.tile_&]:px-0 [.qx-settings_.tiles.sm_.tile_&]:h-[16px] [.qx-settings_.tiles.sm_.tile.on_&]:bg-transparent [.qx-settings_.tiles.sm_.tile.on_&]:bg-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:w-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:h-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:fill-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-current [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-[1.5] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linecap:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linejoin:round]" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M6 1.3v4.2M3.4 2.9a4 4 0 1 0 5.2 0"/></svg>',
    bolt: '<svg class="[.qx-pop_.quit_&]:w-[9px] [.qx-pop_.quit_&]:h-[11px] [.qx-pop_.row_.pw_&]:w-[11px] [.qx-pop_.row_.pw_&]:h-[11px]" viewBox="0 0 13 16"><path d="M8 0L0 9.2h5.2L4.4 16 13 6.4H7.6z" fill="currentColor"/></svg>',
    more: '<svg class="w-[11px] h-[11px]" viewBox="0 0 12 12" fill="currentColor"><circle cx="2.2" cy="6" r="1.1"/><circle cx="6" cy="6" r="1.1"/><circle cx="9.8" cy="6" r="1.1"/></svg>',
    gear: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="2.2"/><path d="M8 1.5v1.8M8 12.7v1.8M1.5 8h1.8M12.7 8h1.8M3.4 3.4l1.3 1.3M11.3 11.3l1.3 1.3M3.4 12.6l1.3-1.3M11.3 4.7l1.3-1.3"/></svg>',
    search: '<svg class="[.qx-pop_.field_&]:w-[11px] [.qx-pop_.field_&]:h-[11px] [.qx-settings.side_.ss_&]:w-[11px] [.qx-settings.side_.ss_&]:h-[11px]" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="5" cy="5" r="3.6"/><path d="M7.8 7.8l2.8 2.8" stroke-linecap="round"/></svg>',
    check: '<svg class="w-[12px] h-[12px]" viewBox="0 0 12 12"><circle cx="6" cy="6" r="6" fill="#fff"/><path d="M3.3 6.2l1.8 1.8 3.6-3.8" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    question: '<svg viewBox="0 0 28 28"><circle cx="14" cy="14" r="13" fill="#FEBC33"/><path d="M10.6 10.8a3.5 3.5 0 1 1 4.6 3.3c-.8.3-1.2.9-1.2 1.7v.6" fill="none" stroke="#2B1D00" stroke-width="2.4" stroke-linecap="round"/><circle cx="14" cy="20.4" r="1.5" fill="#2B1D00"/></svg>',
    warn: '<svg viewBox="0 0 28 28"><path d="M14 2.5l12.5 22H1.5z" fill="#FF453A" stroke="#FF453A" stroke-width="2" stroke-linejoin="round"/><path d="M14 10v7" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><circle cx="14" cy="21" r="1.5" fill="#fff"/></svg>',
    gauge: '<svg class="w-[15px] h-[15px] text-[#FF9F0A]" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M2.2 12a6.3 6.3 0 1 1 11.6 0"/><path d="M8 9.5l3-3"/></svg>',
    cpu: '<svg class="[.menubar_&]:block [.qx-stats_&]:w-[14px] [.qx-stats_&]:h-[14px] [.qx-stats_&]:fill-none [.qx-stats_&]:[stroke:#fff] [.qx-stats_&]:stroke-[1.5] [.qx-stats_&]:[stroke-linecap:round] [.qx-stats_&]:[stroke-linejoin:round] [.qx-settings_.tile_&]:w-full [.qx-settings_.tile_&]:fill-none [.qx-settings_.tile_&]:stroke-current [.qx-settings_.tile_&]:stroke-[1.4] [.qx-settings_.tile_&]:[stroke-linecap:round] [.qx-settings_.tile_&]:[stroke-linejoin:round] [.qx-settings_.tile_&]:[box-sizing:border-box] [.qx-settings_.tile_&]:rounded-[5px] [.qx-overview_.card-icon_&]:w-[16px] [.qx-overview_.card-icon_&]:h-[16px] [.qx-overview_.card-icon_&]:fill-none [.qx-overview_.card-icon_&]:stroke-current [.qx-overview_.card-icon_&]:stroke-[1.6] [.qx-stats-panel_.sd-title_&]:w-[14px] [.qx-stats-panel_.sd-title_&]:h-[14px] [.qx-stats-panel_.sd-title_&]:fill-none [.qx-stats-panel_.sd-title_&]:stroke-current [.qx-stats-panel_.sd-title_&]:stroke-[1.4] [.qx-stats-panel_.sd-title_&]:[stroke-linecap:round] [.qx-stats-panel_.sd-title_&]:[stroke-linejoin:round] [.qx-settings_.tiles.sm_.tile_&]:py-[1px] [.qx-settings_.tiles.sm_.tile_&]:px-0 [.qx-settings_.tiles.sm_.tile_&]:h-[16px] [.qx-settings_.tiles.sm_.tile_&]:bg-transparent [.qx-settings_.tiles.sm_.tile_&]:bg-none" viewBox="0 0 16 16"><rect x="3.5" y="3.5" width="9" height="9" rx="1.6"/><rect x="6" y="6" width="4" height="4" rx=".6"/><path d="M6 1.5v2M10 1.5v2M6 12.5v2M10 12.5v2M1.5 6h2M1.5 10h2M12.5 6h2M12.5 10h2"/></svg>',
    mem: '<svg class="[.menubar_&]:block [.qx-stats_&]:w-[14px] [.qx-stats_&]:h-[14px] [.qx-stats_&]:fill-none [.qx-stats_&]:[stroke:#fff] [.qx-stats_&]:stroke-[1.5] [.qx-stats_&]:[stroke-linecap:round] [.qx-stats_&]:[stroke-linejoin:round] [.qx-stats-panel_.sd-title_&]:w-[14px] [.qx-stats-panel_.sd-title_&]:h-[14px] [.qx-stats-panel_.sd-title_&]:fill-none [.qx-stats-panel_.sd-title_&]:stroke-current [.qx-stats-panel_.sd-title_&]:stroke-[1.4] [.qx-stats-panel_.sd-title_&]:[stroke-linecap:round] [.qx-stats-panel_.sd-title_&]:[stroke-linejoin:round]" viewBox="0 0 16 16"><rect x="1.5" y="4.5" width="13" height="6.5" rx="1"/><path d="M4 7v1.5M6.5 7v1.5M9 7v1.5M11.5 7v1.5M3 11v2M6 11v2M10 11v2M13 11v2"/></svg>',
    gpu: '<svg class="w-[14px] h-[14px] fill-none [stroke:#fff] stroke-[1.5] [stroke-linecap:round] [stroke-linejoin:round] [.menubar_&]:block" viewBox="0 0 16 16"><path d="M8 1.6l5.6 3.2v6.4L8 14.4 2.4 11.2V4.8z"/><path d="M2.4 4.8L8 8l5.6-3.2M8 8v6.4"/></svg>',
    batt: '<svg viewBox="0 0 22 12"><rect x="1" y="1.5" width="17" height="9" rx="2.6" fill="none" stroke="#fff" stroke-opacity=".9" stroke-width="1.1"/><rect x="2.8" y="3.3" width="11.4" height="5.4" rx="1.3" fill="#fff" stroke="none"/><path d="M19.6 4.6v2.8c.7-.2 1.1-.8 1.1-1.4s-.4-1.2-1.1-1.4z" fill="#fff" stroke="none" fill-opacity=".6"/></svg>',
    eye: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8z"/><circle cx="8" cy="8" r="2"/></svg>',
    eyeOff: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8z"/><circle cx="8" cy="8" r="2"/><path d="M2.5 2.5l11 11"/></svg>',
    refresh: '<svg class="[.qx-menu_.mi_&]:w-[14px] [.qx-menu_.mi_&]:h-[14px] [.qx-menu_.mi_&]:flex-none [.qx-menu_.mi_&]:fill-none [.qx-menu_.mi_&]:stroke-current [.qx-menu_.mi_&]:stroke-[1.6] [.qx-menu_.mi_&]:[stroke-linecap:round] [.qx-menu_.mi_&]:[stroke-linejoin:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:w-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:h-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:fill-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-current [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-[1.5] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linecap:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M13.5 6.5A5.6 5.6 0 0 0 3.2 4.6M2.5 9.5a5.6 5.6 0 0 0 10.3 1.9M3 1.8v3h3M13 14.2v-3h-3"/></svg>',
    undo: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M5 3L2 6l3 3"/><path d="M2 6h7.5a4.5 4.5 0 0 1 0 9H6"/></svg>',
    settings: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><circle cx="8" cy="8" r="2.4"/><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"/></svg>',
    help: '<svg class="[.qx-menu_.mi_&]:w-[14px] [.qx-menu_.mi_&]:h-[14px] [.qx-menu_.mi_&]:flex-none [.qx-menu_.mi_&]:fill-none [.qx-menu_.mi_&]:stroke-current [.qx-menu_.mi_&]:stroke-[1.6] [.qx-menu_.mi_&]:[stroke-linecap:round] [.qx-menu_.mi_&]:[stroke-linejoin:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:w-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:h-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:fill-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-current [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-[1.5] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linecap:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linejoin:round]" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6.3"/><path d="M6.2 6.2a1.9 1.9 0 1 1 2.6 1.8c-.5.2-.8.6-.8 1.1v.4M8 11.6v.2"/></svg>',
    sparkles: '<svg class="[.qx-menu_.mi_&]:w-[14px] [.qx-menu_.mi_&]:h-[14px] [.qx-menu_.mi_&]:flex-none [.qx-menu_.mi_&]:fill-none [.qx-menu_.mi_&]:stroke-current [.qx-menu_.mi_&]:stroke-[1.6] [.qx-menu_.mi_&]:[stroke-linecap:round] [.qx-menu_.mi_&]:[stroke-linejoin:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:w-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:h-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:fill-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-current [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-[1.5] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linecap:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M8 1.8l1.4 3.6 3.6 1.4-3.6 1.4L8 11.8 6.6 8.2 3 6.8l3.6-1.4z"/></svg>',
    info: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6.3"/><path d="M8 7.2v4M8 4.8v.2"/></svg>',
    quit: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M8 1.8v6M4.6 3.8a5.4 5.4 0 1 0 6.8 0"/></svg>',
    boltLine: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M9 1.5L3 9h4.5L7 14.5 13 7H8.5z"/></svg>',
    restart: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M13.5 8a5.5 5.5 0 1 1-1.6-3.9M13.5 2v3.6H10"/></svg>',
    others: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><rect x="2" y="5" width="9" height="8" rx="1.5"/><path d="M5 3h8a1 1 0 0 1 1 1v6M9 9h-5"/></svg>',
    nosign: '<svg class="[.qx-menu_.mi_&]:w-[14px] [.qx-menu_.mi_&]:h-[14px] [.qx-menu_.mi_&]:flex-none [.qx-menu_.mi_&]:fill-none [.qx-menu_.mi_&]:stroke-current [.qx-menu_.mi_&]:stroke-[1.6] [.qx-menu_.mi_&]:[stroke-linecap:round] [.qx-menu_.mi_&]:[stroke-linejoin:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:w-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:h-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:fill-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-current [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-[1.5] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linecap:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linejoin:round]" viewBox="0 0 16 16"><circle cx="8" cy="8" r="6"/><path d="M3.8 3.8l8.4 8.4"/></svg>',
    finder: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M2 4.5A1.5 1.5 0 0 1 3.5 3H6l1.5 1.5h5A1.5 1.5 0 0 1 14 6v5.5a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>',
    timer: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><circle cx="8" cy="9" r="5.3"/><path d="M8 6.2V9l2 1.3M6.2 1.8h3.6"/></svg>',
    windows: '<svg class="w-[16px] h-[16px] fill-none stroke-current stroke-[1.6]" viewBox="0 0 16 16"><rect x="1.5" y="4" width="10" height="9" rx="1.4"/><path d="M4.5 4V3a1 1 0 0 1 1-1H14a1 1 0 0 1 .5.9V10a1 1 0 0 1-1 1h-2"/></svg>',
    chev: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M6 3.5L10.5 8 6 12.5"/></svg>',
    trash: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><path d="M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.6 8.5h5.8l.6-8.5"/></svg>',
    alarm: '<svg class="w-[14px] h-[14px] flex-none fill-none stroke-current stroke-[1.6] [stroke-linecap:round] [stroke-linejoin:round]" viewBox="0 0 16 16"><circle cx="8" cy="9" r="5"/><path d="M8 6.5V9l1.6 1M2.5 4l2-1.8M13.5 4l-2-1.8"/></svg>',
    network: '<svg class="[.menubar_&]:block [.qx-stats_&]:w-[14px] [.qx-stats_&]:h-[14px] [.qx-stats_&]:fill-none [.qx-stats_&]:[stroke:#fff] [.qx-stats_&]:stroke-[1.5] [.qx-stats_&]:[stroke-linecap:round] [.qx-stats_&]:[stroke-linejoin:round] [.qx-pop_.tabbar_&]:w-[12px] [.qx-pop_.tabbar_&]:h-[12px] [.qx-overview_.card-icon_&]:w-[16px] [.qx-overview_.card-icon_&]:h-[16px] [.qx-overview_.card-icon_&]:fill-none [.qx-overview_.card-icon_&]:stroke-current [.qx-overview_.card-icon_&]:stroke-[1.6] [.qx-settings.side_.dt_.sec_.sec-icon_&]:w-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:h-[12px] [.qx-settings.side_.dt_.sec_.sec-icon_&]:fill-none [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-current [.qx-settings.side_.dt_.sec_.sec-icon_&]:stroke-[1.5] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linecap:round] [.qx-settings.side_.dt_.sec_.sec-icon_&]:[stroke-linejoin:round]" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="6.2"/><path d="M1.8 8h12.4M8 1.8c1.8 1.9 2.6 3.9 2.6 6.2S9.8 12.3 8 14.2M8 1.8C6.2 3.7 5.4 5.7 5.4 8s.8 4.3 2.6 6.2"/></svg>',
    grid: '<svg class="w-[12px] h-[12px]" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2.2" y="2.2" width="4.6" height="4.6" rx="1"/><rect x="9.2" y="2.2" width="4.6" height="4.6" rx="1"/><rect x="2.2" y="9.2" width="4.6" height="4.6" rx="1"/><rect x="9.2" y="9.2" width="4.6" height="4.6" rx="1"/></svg>',
    sliders: '<svg class="w-[13px] h-[13px]" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M2 4h7M12 4h2M2 8h2M7 8h7M2 12h5M10 12h4"/><circle cx="10.5" cy="4" r="1.5"/><circle cx="5.5" cy="8" r="1.5"/><circle cx="8.5" cy="12" r="1.5"/></svg>',
    trace: '<svg viewBox="0 0 16 16"><circle cx="4" cy="3.5" r="1.6"/><circle cx="4" cy="12.5" r="1.6"/><circle cx="12" cy="8" r="1.6"/><path d="M4 5.1v5.8M5.4 4.3l5.2 2.9"/></svg>',
    folder: '<svg viewBox="0 0 16 16"><path d="M2 4.5A1.5 1.5 0 0 1 3.5 3H6l1.5 1.5h5A1.5 1.5 0 0 1 14 6v5.5a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>',
    copy: '<svg viewBox="0 0 16 16"><rect x="5" y="5" width="8.5" height="8.5" rx="1.6"/><path d="M11 5V3.6A1.1 1.1 0 0 0 9.9 2.5H3.6a1.1 1.1 0 0 0-1.1 1.1v6.3A1.1 1.1 0 0 0 3.6 11H5"/></svg>',
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

  const generic = '<svg class="gen [.qx-pop_.row_&]:w-[18px] [.qx-pop_.row_&]:h-[18px] [.qx-pop_.row_&]:flex-none [.qx-rescue_.r_&]:w-[18px] [.qx-rescue_.r_&]:h-[18px]" viewBox="0 0 18 18"><rect x="1" y="1" width="16" height="16" rx="4" fill="#4A494E"/><rect x="1" y="1" width="16" height="16" rx="4" fill="url(#qxg)" opacity=".5"/><path d="M5.5 6.5h7M5.5 9h7M5.5 11.5h4.5" stroke="#C9C8CE" stroke-width="1.3" stroke-linecap="round"/><defs><linearGradient id="qxg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".25"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient></defs></svg>';
  const icon = a => a.i ? `<img class="[.qx-pop_.row_&]:w-[18px] [.qx-pop_.row_&]:h-[18px] [.qx-pop_.row_&]:flex-none [.qx-rescue_.r_&]:w-[18px] [.qx-rescue_.r_&]:h-[18px]" src="${A}icons/${a.i}.png" alt="">` : generic;


  function row(a, o) {
    const sel = o.selected === 'all' ? !o.unselected.includes(a.n) : o.selected.includes(a.n);
    const cls = ['row'];
    if (o.hover === a.n) cls.push('hover');
    if (o.hl === a.n) cls.push('hl');
    const style = o.rowStyle && o.rowStyle[a.n] ? ` style="${o.rowStyle[a.n]}"` : '';
    const pw = o.force ? 'pw force' : (o.hover === a.n ? 'pw on' : 'pw');
    const use = o.usage && o.usage[a.n] ? o.usage[a.n] : a.u;
    const hot = o.hot && o.hot.includes(a.n) ? ' hot' : '';
    return `<div class="${cls.join(' ')} py-0 pr-[8px] pl-[6px] my-0 mx-[4px] gap-[5px] overflow-hidden relative h-[25px] flex items-center rounded-[4px] text-[12.5px] [&.row.hl]:bg-[rgba(254,188,51,.12)] [&.row.hl]:shadow-[inset_0_0_0_1px_rgba(254,188,51,.3)] [&.row.hover]:bg-[rgba(255,255,255,.07)]" data-app="${a.n}"${style}><span class="qx-cb${sel ? ' on' : ''} place-items-center w-[14px] h-[14px] flex-none rounded-[3px] bg-[rgba(255,255,255,.1)] grid [&.on]:bg-[var(--qx-gold)] [&.on]:after:[border-bottom:1.8px_solid_rgba(0,0,0,.9)] [&.on]:after:[border-left:1.8px_solid_rgba(0,0,0,.9)] [&.on]:after:content-[''] [&.on]:after:w-[7px] [&.on]:after:h-[3.5px] [&.on]:after:[transform:rotate(-45deg)_translate(.5px,-.8px)]"></span>${icon(a)}<span class="name overflow-hidden flex-1 min-w-0 whitespace-nowrap [text-overflow:ellipsis]">${a.n}${a.tag ? `<span class="tag">${a.tag}</span>` : ''}</span><span class="use${hot} w-[46px] text-right font-normal text-[10.5px] leading-[1] font-['QX_Mono',monospace] text-[var(--qx-sub)]">${use}</span><span class="more${o.moreOn === a.n ? ' on' : ''} place-items-center w-[16px] h-[16px] grid text-[var(--qx-sub)] [&.on]:text-white [&.on]:bg-[rgba(255,255,255,.14)] [&.on]:rounded-[4px]">${S.more}</span><span class="${pw} place-items-center w-[18px] h-[18px] rounded-[50%] grid text-[var(--qx-sub)] [&.pw.on]:text-[rgba(0,0,0,.85)] [&.pw.on]:bg-[var(--qx-gold)] [&.pw.force]:text-white [&.pw.force]:bg-[#F04632]">${o.force ? S.bolt : S.power}</span></div>`;
  }

  function popover(o = {}) {
    o = Object.assign({ selected: 'all', unselected: [], apps: APPS, arrowX: 165, footer: 'Quit one, some, or all apps' }, o);
    const list = o.apps.map(a => row(a, o)).join('');
    const count = o.selected === 'all' ? o.apps.length - o.unselected.length : o.selected.length;
    const isAll = o.selected === 'all' && o.unselected.length === 0;
    let title = o.button || (o.force ? (isAll ? 'Force Quit All' : 'Force Quit Selected') : (isAll ? 'Quit All' : 'Quit Selected'));
    const off = o.buttonOff || count === 0;
    const btn = `<div class="quit${off ? ' off' : ''}${o.press ? ' press' : ''} mx-[8px] mt-[7px] mb-[4px] gap-[5px] h-[24px] rounded-[6px] flex items-center justify-center bg-[linear-gradient(var(--qx-gold),var(--qx-gold-deep))] bg-transparent text-[rgba(0,0,0,.88)] text-[12px] font-bold shadow-[0_1px_2px_rgba(254,188,51,.18)] [&.off]:bg-none [&.off]:bg-[rgba(255,255,255,.08)] [&.off]:text-[rgba(255,255,255,.35)] [&.off]:shadow-none [&.press]:[filter:brightness(.86)]" data-role="quit">${o.force && !off ? S.bolt : ''}${title}</div>`;
    const headCb = isAll ? 'on' : (count > 0 ? 'part' : '');
    return `<div class="qx-pop${o.glass ? ' glass' : ''}${o.tabs ? ' wide' : ''} relative w-[330px] font-['Inter',-apple-system,system-ui,sans-serif] text-[var(--qx-ink)] antialiased tracking-[-.003em] [&.wide]:w-[330px]">${chrome(o.arrowX, o.glass)}<div style="height:12px"></div><div class="body" style="position:relative;z-index:1;border-radius:14px;overflow:hidden"><div style="height:5px"></div>${o.tabs ? tabbar('apps') : ''}${btn}<div class="search mx-[8px] mt-0 mb-[4px] gap-[8px] flex items-center [.pg-install_&]:py-0 [.pg-install_&]:px-[9px]"><span class="qx-cb ${headCb} place-items-center w-[14px] h-[14px] flex-none rounded-[3px] bg-[rgba(255,255,255,.1)] grid [&.on]:bg-[var(--qx-gold)] [&.part]:bg-[var(--qx-gold)] [&.on]:after:[border-bottom:1.8px_solid_rgba(0,0,0,.9)] [&.on]:after:[border-left:1.8px_solid_rgba(0,0,0,.9)] [&.on]:after:content-[''] [&.on]:after:w-[7px] [&.on]:after:h-[3.5px] [&.on]:after:[transform:rotate(-45deg)_translate(.5px,-.8px)] [&.part]:after:content-[''] [&.part]:after:w-[6px] [&.part]:after:h-[2px] [&.part]:after:rounded-[1px] [&.part]:after:bg-[rgba(0,0,0,.9)]"></span><div class="field py-0 px-[7px] gap-[5px] flex-1 h-[24px] rounded-[6px] flex items-center text-[11.5px] text-[var(--qx-sub)] bg-[rgba(0,0,0,.18)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.08)]">${S.search}Search</div></div><div class="list py-[2px] px-0 gap-[2px] flex flex-col">${list}</div><div class="foot px-[10px] pt-[3px] pb-[7px] flex items-center text-[11px] text-[var(--qx-sub)]"><span>${o.footer}</span><span class="gear${o.gearOn ? ' on' : ''} ml-auto place-items-center w-[18px] h-[18px] grid rounded-[5px] text-[var(--qx-sub)] [&.on]:text-white [&.on]:bg-[rgba(255,255,255,.14)]" data-role="gear">${S.sliders}</span></div>${o.overlay || ''}${o.toast ? `<div class="qx-toast py-[7px] px-[14px] gap-[6px] absolute left-[50%] bottom-[36px] [transform:translateX(-50%)] z-[6] flex items-center rounded-[999px] bg-[rgba(0,0,0,.78)] text-white text-[12px] font-medium whitespace-nowrap">${S.check}${o.toast}</div>` : ''}</div></div>`;
  }

  function tabbar(active) {
    return `<div class="tabbar p-[2px] mx-[8px] mt-[7px] mb-0 gap-[2px] h-[26px] rounded-[7px] flex bg-[rgba(255,255,255,.06)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.08)]"><span class="${active === 'apps' ? 'on' : ''} gap-[5px] flex-1 rounded-[5px] flex items-center justify-center text-[12px] font-semibold text-[rgba(255,255,255,.72)] [&.on]:text-[rgba(0,0,0,.88)] [&.on]:bg-[linear-gradient(var(--qx-gold),var(--qx-gold-deep))]" data-tab="apps">${S.grid}Apps</span><span class="${active === 'ports' ? 'on' : ''} gap-[5px] flex-1 rounded-[5px] flex items-center justify-center text-[12px] font-semibold text-[rgba(255,255,255,.72)] [&.on]:text-[rgba(0,0,0,.88)] [&.on]:bg-[linear-gradient(var(--qx-gold),var(--qx-gold-deep))]" data-tab="ports">${S.network}Ports</span></div>`;
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
    const badges = `${x.docker ? '<span class="badge docker py-[1px] px-[4px] ml-[5px] flex-none rounded-[3px] text-[9.5px] font-semibold bg-[rgba(10,132,255,.18)] text-[#4DA3FF]">docker</span>' : ''}<span class="badge ${x.exp === 'Public' ? 'pub' : 'loc'} py-[1px] px-[4px] ml-[5px] flex-none rounded-[3px] text-[9.5px] font-semibold [&.loc]:bg-[rgba(255,255,255,.1)] [&.loc]:text-[rgba(235,235,245,.6)] [&.pub]:bg-[rgba(255,69,58,.16)] [&.pub]:text-[#FF6B60]">${x.exp}</span>`;
    return `<div class="${cls.join(' ')} py-0 pr-[8px] pl-[6px] my-0 mx-[4px] gap-[5px] overflow-hidden relative h-[25px] flex items-center rounded-[4px] text-[12.5px] [&.row.hover]:bg-[rgba(255,255,255,.07)]" data-port="${x.p}"${style}><span class="qx-cb${sel ? ' on' : ''} place-items-center w-[14px] h-[14px] flex-none rounded-[3px] bg-[rgba(255,255,255,.1)] grid [&.on]:bg-[var(--qx-gold)] [&.on]:after:[border-bottom:1.8px_solid_rgba(0,0,0,.9)] [&.on]:after:[border-left:1.8px_solid_rgba(0,0,0,.9)] [&.on]:after:content-[''] [&.on]:after:w-[7px] [&.on]:after:h-[3.5px] [&.on]:after:[transform:rotate(-45deg)_translate(.5px,-.8px)]"></span>${icon(x)}<span class="pnum py-[2px] px-[5px] flex-none rounded-[4px] bg-[rgba(255,255,255,.08)] font-semibold text-[11px] leading-[1.2] font-['QX_Mono',monospace] text-[rgba(255,255,255,.92)]">:${x.p}</span><span class="name overflow-hidden flex items-center flex-1 min-w-0 whitespace-nowrap [text-overflow:ellipsis]">${x.n}${badges}</span><span class="use w-[50px] text-right font-normal text-[10.5px] leading-[1] font-['QX_Mono',monospace] text-[var(--qx-sub)]">${x.mem}</span><span class="more${o.moreOn === x.p ? ' on' : ''} place-items-center w-[16px] h-[16px] grid text-[var(--qx-sub)]">${S.more}</span><span class="${pw} place-items-center w-[18px] h-[18px] rounded-[50%] grid text-[var(--qx-sub)] [&.pw.on]:text-[rgba(0,0,0,.85)] [&.pw.on]:bg-[var(--qx-gold)]">${o.force ? S.bolt : S.power}</span></div>`;
  }

  function ports(o = {}) {
    o = Object.assign({ selected: [], unselected: [], ports: PORTS, arrowX: 165, footer: 'Free up occupied ports 🧹' }, o);
    const list = o.ports.map(x => portRow(x, o)).join('');
    const count = o.selected === 'all' ? o.ports.length - o.unselected.length : o.selected.length;
    const isAll = o.selected === 'all' && o.unselected.length === 0;
    const noun = count === 1 ? 'Port' : 'Ports';
    const title = o.force ? (isAll ? 'Force Kill All Ports' : (count ? `Force Kill ${count} ${noun}` : 'Force Kill Selected Ports')) : (isAll ? 'Kill All Ports' : (count ? `Kill ${count} ${noun}` : 'Kill Selected Ports'));
    const btn = `<div class="quit${count === 0 ? ' off' : ''} mx-[8px] mt-[7px] mb-[4px] gap-[5px] h-[24px] rounded-[6px] flex items-center justify-center bg-[linear-gradient(var(--qx-gold),var(--qx-gold-deep))] bg-transparent text-[rgba(0,0,0,.88)] text-[12px] font-bold shadow-[0_1px_2px_rgba(254,188,51,.18)] [&.off]:bg-none [&.off]:bg-[rgba(255,255,255,.08)] [&.off]:text-[rgba(255,255,255,.35)] [&.off]:shadow-none" data-role="quit">${o.force && count ? S.bolt : ''}${title}</div>`;
    const headCb = isAll ? 'on' : (count > 0 ? 'part' : '');
    return `<div class="qx-pop wide${o.glass ? ' glass' : ''} relative w-[330px] font-['Inter',-apple-system,system-ui,sans-serif] text-[var(--qx-ink)] antialiased tracking-[-.003em]">${chrome(o.arrowX, o.glass)}<div style="height:12px"></div><div class="body" style="position:relative;z-index:1;border-radius:14px;overflow:hidden"><div style="height:5px"></div>${tabbar('ports')}${btn}<div class="search mx-[8px] mt-0 mb-[4px] gap-[8px] flex items-center"><span class="qx-cb ${headCb} place-items-center w-[14px] h-[14px] flex-none rounded-[3px] bg-[rgba(255,255,255,.1)] grid [&.part]:bg-[var(--qx-gold)] [&.part]:after:content-[''] [&.part]:after:w-[6px] [&.part]:after:h-[2px] [&.part]:after:rounded-[1px] [&.part]:after:bg-[rgba(0,0,0,.9)]"></span><div class="field py-0 px-[7px] gap-[5px] flex-1 h-[24px] rounded-[6px] flex items-center text-[11.5px] text-[var(--qx-sub)] bg-[rgba(0,0,0,.18)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.08)]">${S.search}Search ports, apps, folders</div></div><div class="list py-[2px] px-0 gap-[2px] flex flex-col">${list}</div><div class="foot px-[10px] pt-[3px] pb-[7px] flex items-center text-[11px] text-[var(--qx-sub)]"><span>${o.footer}</span><span class="gear${o.gearOn ? ' on' : ''} ml-auto place-items-center w-[18px] h-[18px] grid rounded-[5px] text-[var(--qx-sub)]" data-role="gear">${S.sliders}</span></div>${o.overlay || ''}${o.toast ? `<div class="qx-toast py-[7px] px-[14px] gap-[6px] absolute left-[50%] bottom-[36px] [transform:translateX(-50%)] z-[6] flex items-center rounded-[999px] bg-[rgba(0,0,0,.78)] text-white text-[12px] font-medium whitespace-nowrap">${S.check}${o.toast}</div>` : ''}</div></div>`;
  }

  function confirm(o) {
    const noun = o.count === 1 ? 'App' : 'Apps';
    const title = o.force ? (o.all ? `Force Quit All ${noun}?` : `Force Quit ${o.count} ${noun}?`) : (o.all ? `Quit All ${noun}?` : `Quit ${o.count} ${noun}?`);
    const ok = o.force ? (o.all ? 'Force Quit All' : 'Force Quit') : (o.all ? 'Quit All' : 'Quit');
    return `<div class="qx-scrim inset-0 place-items-center absolute bg-[rgba(0,0,0,.45)] grid z-[5]"><div class="qx-confirm py-[12px] px-[14px] gap-[10px] w-[214px] min-h-[132px] rounded-[12px] bg-[#323134] text-center shadow-[0_0_0_.8px_rgba(255,255,255,.12),0_3px_8px_rgba(0,0,0,.4)] flex flex-col items-center"><span class="ic w-[28px] h-[28px]">${o.force ? S.warn : S.question}</span><div><b class="block text-[13px] font-semibold">${title}</b><small class="mt-[3px] block text-[11px] text-[var(--qx-sub)]">This will close ${o.count} ${o.count === 1 ? 'application.' : 'applications.'}</small></div><div class="btns mt-[2px] gap-[8px] flex w-full"><span class="place-items-center flex-1 h-[24px] rounded-[6px] grid text-[11.5px] font-medium bg-[rgba(255,255,255,.07)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.12)]">Cancel</span><span class="p${o.force ? ' force' : ''}${o.press ? ' press' : ''} place-items-center flex-1 h-[24px] rounded-[6px] grid text-[11.5px] font-bold bg-transparent bg-[linear-gradient(var(--qx-gold),var(--qx-gold-deep))] shadow-none text-[rgba(0,0,0,.88)] [&.press]:[filter:brightness(.85)]" data-role="confirm">${ok}</span></div></div></div>`;
  }

  function menu(items) {
    return `<div class="qx-menu p-[5px] w-[236px] rounded-[9px] font-['Inter',-apple-system,system-ui,sans-serif] text-[13px] text-[rgba(255,255,255,.92)] bg-[rgba(40,38,40,.9)] [backdrop-filter:blur(40px)_saturate(1.6)] [-webkit-backdrop-filter:blur(40px)_saturate(1.6)] shadow-[0_0_0_.5px_rgba(255,255,255,.18),0_0_0_1px_rgba(0,0,0,.55),0_20px_44px_rgba(0,0,0,.5)]">${items.map(m => {
      if (m === '-') return '<hr class="my-[4px] mx-[8px] [border:0] h-[1px] bg-[rgba(255,255,255,.1)]">';
      const lead = m.dot ? '<span class="dot my-0 mx-[2.5px] w-[9px] h-[9px] rounded-[50%] bg-[var(--qx-red)]"></span>' : (m.icon ? S[m.icon] : '<span style="width:14px"></span>');
      const tail = m.chev ? `<span class="chev ml-auto opacity-[.55]">${S.chev}</span>` : (m.k ? `<span class="k ml-auto text-[rgba(255,255,255,.42)] [.qx-menu_.mi.on_&]:text-[rgba(255,255,255,.75)]">${m.k}</span>` : '');
      return `<div class="mi${m.on ? ' on' : ''} py-0 px-[8px] gap-[8px] h-[23px] flex items-center rounded-[5px] whitespace-nowrap [&.on]:bg-[#0A63D8] [&.on]:text-white" ${m.id ? `id="${m.id}"` : ''}>${lead}<span>${m.t}</span>${tail}</div>`;
    }).join('')}</div>`;
  }

  function stats(o) {
    const seg = (k, inner) => `<span data-k="${k}" class="gap-[4px] inline-flex items-center">${inner}</span>`;
    const parts = {
      cpu: o.cpu != null ? seg('cpu', `${S.cpu}${o.cpu}`) : '',
      gpu: o.gpu != null ? seg('gpu', `${S.gpu}${o.gpu}`) : '',
      mem: o.mem != null ? seg('mem', `${S.mem}${o.mem}`) : '',
      bat: o.bat != null ? seg('bat', `${S.batt.replace('<svg', '<svg class="w-[14px] h-[14px] fill-none [stroke:#fff] stroke-[1.5] [stroke-linecap:round] [stroke-linejoin:round] [.menubar_&]:block" style="width:22px;height:12px"')}${o.bat}`) : '',
      ports: o.ports != null ? seg('ports', `${S.network}${o.ports}`) : '',
      clean: o.clean != null ? seg('clean', `<svg class="[.menubar_&]:block" width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"><path d="M7 1.8l1.2 3.4 3.4 1.2-3.4 1.2L7 11l-1.2-3.4L2.4 6.4l3.4-1.2z"/><path d="M12.3 9.6l.6 1.6 1.6.6-1.6.6-.6 1.6-.6-1.6-1.6-.6 1.6-.6z"/></svg>${o.clean}`) : '',
    };
    const order = o.order || ['cpu', 'gpu', 'mem', 'bat', 'ports', 'clean'];
    return `<div class="qx-stats py-0 px-[8px] gap-[12px] flex items-center h-[22px] rounded-[5px] text-[13px] font-medium text-[rgba(255,255,255,.95)] tabular-nums whitespace-nowrap [&.active]:bg-[rgba(255,255,255,.22)]">${order.map(k => parts[k] || '').join('')}</div>`;
  }

  function rescue(o) {
    const rows = o.targets.map(t => `<div class="r py-0 px-[12px] gap-[7px] h-[25px] flex items-center text-[12.5px]"><span class="qx-cb on place-items-center w-[14px] h-[14px] flex-none rounded-[3px] bg-[var(--qx-gold)] grid after:[border-bottom:1.8px_solid_rgba(0,0,0,.9)] after:[border-left:1.8px_solid_rgba(0,0,0,.9)] after:content-[''] after:w-[7px] after:h-[3.5px] after:[transform:rotate(-45deg)_translate(.5px,-.8px)]"></span>${icon(t)}<span>${t.n}</span><em class="ml-auto [font-style:normal] text-[11px] font-medium text-[#FF9F0A] tabular-nums">${t.v}</em></div>`).join('');
    return `<div class="qx-rescue relative w-[270px] font-['Inter',-apple-system,system-ui,sans-serif] text-[var(--qx-ink)]">${chrome(o.arrowX || 135, o.glass)}<div style="height:12px"></div><div class="body" style="position:relative;z-index:1;border-radius:14px;padding:14px 0 16px;display:flex;flex-direction:column;gap:12px"><div class="h py-0 px-[12px] gap-[7px] flex items-center text-[12.5px] font-semibold">${S.gauge}${o.title}</div><p class="py-0 px-[12px] m-0 text-[11px] text-[var(--qx-sub)] leading-[1.4]">${o.detail}</p><div class="qx-card my-0 mx-[12px] rounded-[7px] bg-[rgba(255,255,255,.035)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.09)]"><div class="sel py-0 px-[12px] gap-[8px] h-[27px] flex items-center text-[11.5px] font-medium"><span class="qx-cb on place-items-center w-[14px] h-[14px] flex-none rounded-[3px] bg-[var(--qx-gold)] grid after:[border-bottom:1.8px_solid_rgba(0,0,0,.9)] after:[border-left:1.8px_solid_rgba(0,0,0,.9)] after:content-[''] after:w-[7px] after:h-[3.5px] after:[transform:rotate(-45deg)_translate(.5px,-.8px)]"></span>Deselect All<em class="ml-auto [font-style:normal] text-[11px] text-[var(--qx-sub)] font-normal">${o.targets.length} apps</em></div>${rows}</div><div class="btns py-0 px-[12px] gap-[8px] flex"><span class="place-items-center flex-1 h-[24px] rounded-[6px] grid text-[11.5px] font-medium bg-[rgba(255,255,255,.07)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.12)]">Cancel</span><span class="p place-items-center flex-1 h-[24px] rounded-[6px] grid text-[11.5px] font-bold bg-transparent bg-[linear-gradient(var(--qx-gold),var(--qx-gold-deep))] shadow-none text-[rgba(0,0,0,.88)]">Quit ${o.targets.length} apps</span></div></div></div>`;
  }

  function note(o) {
    return `<div class="qx-note py-[11px] px-[13px] gap-[11px] w-[344px] rounded-[16px] flex font-['Inter',-apple-system,system-ui,sans-serif] text-white bg-[rgba(46,43,41,.78)] [backdrop-filter:blur(30px)_saturate(1.6)] [-webkit-backdrop-filter:blur(30px)_saturate(1.6)] shadow-[inset_0_0_0_.5px_rgba(255,255,255,.18),0_10px_30px_rgba(0,0,0,.35)]"><img class="w-[36px] h-[36px] flex-none" src="${A}icon.png" alt=""><div style="flex:1;min-width:0"><div class="t flex justify-between text-[13px] font-semibold"><span>${o.title}</span><small class="font-normal text-[12px] text-[rgba(255,255,255,.55)]">${o.time || 'now'}</small></div><p class="mx-0 mt-[2px] mb-0 text-[12.5px] leading-[1.35] text-[rgba(255,255,255,.85)]">${o.body}</p></div></div>`;
  }

  const P = a => `rgba(255,255,255,${a})`;
  const AC = a => `rgba(254,188,51,${a})`;
  const INK = 'rgba(255,255,255,.86)';
  const SUB = 'rgba(235,235,245,.6)';
  const GOLD = '#FEBC33';
  const GOLD2 = '#E89B00';
  const WIN_BG = '#262527';
  const SIDE_BG = '#2E2D30';

  const SF = {
    magnifyingglass: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.3 15.3l5.2 5.2"/>',
    'square.grid.2x2': '<rect x="3.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.6"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.6"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.6"/>',
    gearshape: '<circle cx="12" cy="12" r="3"/><path d="M12 2.8l1.6 2.3 2.7-.7.5 2.8 2.8.5-.7 2.7 2.3 1.6-2.3 1.6.7 2.7-2.8.5-.5 2.8-2.7-.7L12 21.2l-1.6-2.3-2.7.7-.5-2.8-2.8-.5.7-2.7L2.8 12l2.3-1.6-.7-2.7 2.8-.5.5-2.8 2.7.7z"/>',
    command: '<path d="M15 6v12a3 3 0 1 0 3-3H6a3 3 0 1 0 3 3V6a3 3 0 1 0-3 3h12a3 3 0 1 0-3-3"/>',
    timer: '<path d="M10 2.5h4M12 14l3-3"/><circle cx="12" cy="14" r="8"/>',
    'slider.horizontal.3': '<path d="M21 5h-7M10 5H3M21 12h-9M8 12H3M21 19h-5M12 19H3M14 3v4M8 10v4M16 17v4"/>',
    nosign: '<circle cx="12" cy="12" r="9.2"/><path d="M5.5 5.5l13 13"/>',
    'xmark.app': '<rect x="3" y="3" width="18" height="18" rx="4.2"/><path d="M9 9l6 6M15 9l-6 6"/>',
    'doc.questionmark': '<path d="M14 2.8H6.5a2 2 0 0 0-2 2v14.4a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8.3z"/><path d="M10 11.2a2 2 0 1 1 2.7 1.9c-.5.2-.7.6-.7 1.1v.4M12 17.6v.1"/>',
    'gearshape.2': '<circle cx="9" cy="9" r="2.2"/><path d="M9 3.5v1.6M9 12.9v1.6M3.5 9h1.6M12.9 9h1.6M5.1 5.1l1.1 1.1M11.8 11.8l1.1 1.1M5.1 12.9l1.1-1.1M11.8 6.2l1.1-1.1"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M16.5 12.6v1.3M16.5 19.1v1.3M12.6 16.5h1.3M19.1 16.5h1.3"/>',
    internaldrive: '<path d="M3.5 14l2.4-8h12.2l2.4 8v4.5h-17z"/><path d="M3.5 14h17M7.5 16.3h.1M10.5 16.3h.1"/>',
    envelope: '<rect x="3" y="5.5" width="18" height="13" rx="2.2"/><path d="M3.6 6.6L12 12.6l8.4-6"/>',
    trash: '<path d="M4 6.5h16M9 6.5V4.3h6v2.2M6 6.5l1 13.2h10l1-13.2M10 10v6M14 10v6"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5.2l3.4 2"/>',
    cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx=".8"/><path d="M9.5 2.5V6M14.5 2.5V6M9.5 18v3.5M14.5 18v3.5M2.5 9.5H6M2.5 14.5H6M18 9.5h3.5M18 14.5h3.5"/>',
    hammer: '<path d="M14 4l6 6-2.4 2.4-6-6zM11.6 6.4L3.5 14.5l3 3 8.1-8.1"/>',
    mug: '<path d="M4.5 8h12v7.5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4z"/><path d="M16.5 10h1.7a2.3 2.3 0 0 1 0 4.6h-1.7M8.5 3.5v2.2M12.5 3.5v2.2"/>',
    leaf: '<path d="M4.5 19.5C4.5 11 9.5 5.2 19.5 4.5c-.4 9.6-5.9 15-15 15z"/><path d="M4.5 19.5l8-8"/>',
    shippingbox: '<path d="M12 3l8.5 4.5v9L12 21l-8.5-4.5v-9z"/><path d="M3.5 7.5L12 12l8.5-4.5M12 12v9M7.8 5.2l8.4 4.5"/>',
    network: '<circle cx="12" cy="12" r="9.2"/><path d="M2.8 12h18.4M12 2.8c2.4 2.5 3.7 5.7 3.7 9.2s-1.3 6.7-3.7 9.2c-2.4-2.5-3.7-5.7-3.7-9.2S9.6 5.3 12 2.8z"/>',
    'bolt.fill': { f: '<path d="M13.5 2L4.5 13.5h6.6l-1.6 8.5 9-11.5h-6.6z"/>' },
    bolt: '<path d="M13.5 2.5L4.8 13.4h6.6l-1.4 8.1 8.7-10.9h-6.6z"/>',
    power: '<path d="M12 3v8.5"/><path d="M17.7 6.5a8 8 0 1 1-11.4 0"/>',
    'power.circle': '<circle cx="12" cy="12" r="9.2"/><path d="M12 7v5"/><path d="M15.3 8.8a4.6 4.6 0 1 1-6.6 0"/>',
    'speaker.wave.2': '<path d="M4 9.2h3.2L11.5 5v14l-4.3-4.2H4z"/><path d="M15 9a4.3 4.3 0 0 1 0 6M17.8 6.4a8 8 0 0 1 0 11.2"/>',
    'arrow.triangle.2.circlepath': '<path d="M20.5 11A8.5 8.5 0 0 0 6 6.3L4 8.4M3.5 13A8.5 8.5 0 0 0 18 17.7l2-2.1"/><path d="M3.8 4v4.6h4.6M20.2 20v-4.6h-4.6"/>',
    'menubar.rectangle': '<rect x="2.8" y="4.5" width="18.4" height="15" rx="3"/><path d="M2.8 9h18.4"/>',
    paintpalette: { s: '<path d="M12 2.8c-5.1 0-9.2 4-9.2 9.2s4.1 9.2 9.2 9.2c.9 0 1.5-.7 1.5-1.5 0-.4-.2-.8-.4-1-.3-.3-.4-.6-.4-1 0-.9.7-1.5 1.5-1.5h1.8c2.8 0 5.1-2.3 5.1-5.1-.1-5-4.2-9.3-9.1-9.3z"/>', f: '<circle cx="7.6" cy="11.4" r="1.25"/><circle cx="9.8" cy="7.2" r="1.25"/><circle cx="14.4" cy="7.2" r="1.25"/><circle cx="17" cy="11.2" r="1.25"/>' },
    'arrow.up.arrow.down': '<path d="M3.5 8L7.5 4l4 4M7.5 4v16M20.5 16l-4 4-4-4M16.5 20V4"/>',
    'cursorarrow.click.2': '<path d="M9.5 9.5l4.8 11.2 1.6-4.8 4.8-1.6z"/><path d="M7.6 3l.7 2.6M3 7.6l2.6.7M13.6 4.5L11.8 6.3M4.5 13.6l1.8-1.8"/>',
    'arrow.counterclockwise': '<path d="M3.5 12a8.5 8.5 0 1 0 2.5-6L3.5 8.5"/><path d="M3.5 3.8v4.7h4.7"/>',
    'moon.zzz': '<path d="M11.2 4.2a7.5 7.5 0 1 0 8.6 9.8 6.2 6.2 0 0 1-8.6-9.8z"/><path d="M15 3.5h4l-4 4h4"/>',
    macwindow: '<rect x="2.8" y="4.2" width="18.4" height="15.6" rx="2.6"/><path d="M2.8 8.6h18.4M5.8 6.4h.1M8 6.4h.1"/>',
    'heart.text.square': '<rect x="3.2" y="3.2" width="17.6" height="17.6" rx="4"/><path d="M7.5 15.5h9M7.5 18h6"/><path d="M12 12.4l-2.3-2.2a1.4 1.4 0 0 1 2.3-1.6 1.4 1.4 0 0 1 2.3 1.6z"/>',
    hourglass: '<path d="M5.5 2.8h13M5.5 21.2h13M7.5 2.8v3.5c0 1.4 4.5 4.3 4.5 5.7 0-1.4 4.5-4.3 4.5-5.7V2.8M7.5 21.2v-3.5c0-1.4 4.5-4.3 4.5-5.7 0 1.4 4.5 4.3 4.5 5.7v3.5"/>',
    'arrow.clockwise': '<path d="M20.5 12a8.5 8.5 0 1 1-2.5-6l2.5 2.5"/><path d="M20.5 3.8v4.7h-4.7"/>',
    'dot.radiowaves.left.and.right': '<circle cx="12" cy="12" r="1.8"/><path d="M15.8 8.2a5.4 5.4 0 0 1 0 7.6M8.2 15.8a5.4 5.4 0 0 1 0-7.6M18.6 5.4a9.3 9.3 0 0 1 0 13.2M5.4 18.6a9.3 9.3 0 0 1 0-13.2"/>',
    'square.stack.3d.up': '<path d="M12 2.8L3 7.4l9 4.6 9-4.6z"/><path d="M3 12l9 4.6 9-4.6M3 16.6l9 4.6 9-4.6"/>',
    'checkmark.shield': '<path d="M12 21.2s7.8-3.5 7.8-9.5V5.6L12 2.8 4.2 5.6v6.1c0 6 7.8 9.5 7.8 9.5z"/><path d="M8.6 12l2.3 2.3 4.5-4.6"/>',
    checklist: '<path d="M10.5 6.5h10M10.5 12h10M10.5 17.5h10M3.5 6.5l1.3 1.3 2.5-2.6M3.5 12l1.3 1.3 2.5-2.6M3.5 17.5l1.3 1.3 2.5-2.6"/>',
    'questionmark.circle': '<circle cx="12" cy="12" r="9.2"/><path d="M9.3 9.3a2.8 2.8 0 0 1 5.4 1c0 1.9-2.7 2.4-2.7 4"/><path d="M12 17.3v.1"/>',
    hare: '<path d="M4 16.5c0-3.3 3.1-6 7-6 1.4 0 2.6.3 3.7.9l1.5-4.6c.3-1 1.5-1.5 2.4-.9.8.5 1 1.5.6 2.3l-1.8 3.9c1.3 1 2.1 2.6 2.1 4.4H4z"/><path d="M8 16.5v3M15 16.5v3M17 12.8h.1"/>',
    speedometer: '<path d="M3.5 17.5a8.5 8.5 0 1 1 17 0"/><path d="M12 15.8l4-4.6"/><circle cx="12" cy="16" r="1"/>',
    'gauge.with.dots.needle.50percent': '<path d="M3.5 17.5a8.5 8.5 0 1 1 17 0"/><path d="M12 16V9.5"/><path d="M6.8 13h.1M8.4 9.6h.1M15.6 9.6h.1M17.2 13h.1"/>',
    'gauge.with.dots.needle.67percent': '<path d="M3.5 17.5a8.5 8.5 0 1 1 17 0"/><path d="M12 16l3.8-5.4"/><path d="M6.8 13h.1M8.4 9.6h.1M12 8.2h.1M17.2 13h.1"/>',
    tortoise: '<path d="M3 15.5c0-4 3.6-7 8-7s7.6 3 7.6 6.3v.7z"/><path d="M18.6 13.6h1.7a1.7 1.7 0 0 0 0-3.4h-1.4M6 15.5v2.8M10 15.5v2.8M14.5 15.5v2.8M7.5 9.6l2.3 5.9M14.5 9.6l-2.3 5.9"/>',
    'rectangle.fill': { f: '<rect x="3" y="5.5" width="18" height="13" rx="2.6"/>' },
    'drop.fill': { f: '<path d="M12 2.6c-2.7 3.6-6.2 7.8-6.2 11.6a6.2 6.2 0 0 0 12.4 0c0-3.8-3.5-8-6.2-11.6z"/>' },
    textformat: '<path d="M2.5 18.5L7.6 5.5l5.1 13M4.4 13.8h6.4"/><circle cx="17.4" cy="15.4" r="3.1"/><path d="M20.5 12v6.5"/>',
    percent: '<path d="M18.5 5.5l-13 13"/><circle cx="7" cy="7" r="2.6"/><circle cx="17" cy="17" r="2.6"/>',
    'clock.badge': '<path d="M20.5 12A8.5 8.5 0 1 1 12 3.5"/><path d="M12 7.5v4.7l3 1.8"/><circle cx="18.6" cy="5.4" r="2.6"/>',
    'arrow.down.right.circle': '<circle cx="12" cy="12" r="9.2"/><path d="M8.6 8.6l6.8 6.8M15.4 9.4v6H9.4"/>',
    'arrow.up.right.circle': '<circle cx="12" cy="12" r="9.2"/><path d="M8.6 15.4l6.8-6.8M9.4 8.6h6v6"/>',
    'textformat.abc': { t: 'abc' },
    'list.bullet': '<path d="M9 6h11.5M9 12h11.5M9 18h11.5"/><path d="M4.2 6h.1M4.2 12h.1M4.2 18h.1" stroke-width="2.6"/>',
    folder: '<path d="M3 6.8a2 2 0 0 1 2-2h4l2 2.2h8a2 2 0 0 1 2 2v8.2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    'folder.fill': { f: '<path d="M2.5 6.6a2.2 2.2 0 0 1 2.2-2.2h4.2l2.1 2.2h8.3a2.2 2.2 0 0 1 2.2 2.2v8.8a2.2 2.2 0 0 1-2.2 2.2H4.7a2.2 2.2 0 0 1-2.2-2.2z"/>' },
    'doc.fill': { f: '<path d="M6.5 2.5h7l5 5v12a2 2 0 0 1-2 2h-10a2 2 0 0 1-2-2v-15a2 2 0 0 1 2-2z"/>' },
    'arrow.triangle.branch': '<path d="M7 3.5v10M7 13.5c0-3 2-5 5-5h2.5M7 13.5v7M17 14.5l-3 3M17 14.5h-3.5"/><circle cx="17" cy="8.5" r="2.4"/>',
    'arrow.up': '<path d="M12 19.5v-15M5.5 11l6.5-6.5 6.5 6.5"/>',
    'arrow.down': '<path d="M12 4.5v15M5.5 13l6.5 6.5 6.5-6.5"/>',
    memorychip: '<rect x="2.8" y="7" width="18.4" height="10" rx="1.6"/><path d="M6.5 17v2.8M10 17v2.8M14 17v2.8M17.5 17v2.8M7 10h10v3.5H7z"/>',
    sparkles: { f: '<path d="M10 3l1.9 5.2L17 10l-5.1 1.9L10 17l-1.9-5.1L3 10l5.1-1.8z"/><path d="M18 3l.8 2.1L21 6l-2.2.8L18 9l-.8-2.2L15 6l2.2-.9zM17.5 15.5l.7 1.7 1.8.8-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.8z"/>' },
    lifepreserver: '<circle cx="12" cy="12" r="9.2"/><circle cx="12" cy="12" r="4"/><path d="M5.5 5.5l3.7 3.7M14.8 14.8l3.7 3.7M18.5 5.5l-3.7 3.7M9.2 14.8l-3.7 3.7"/>',
    swift: { f: '<path d="M19.6 15.4c.1-.3.2-.6.2-.9.7-3.3-1.1-7.2-4.2-9.5 1.4 1.9 2 4.2 1.5 6.2l-.2.6-.2-.1C13.7 9.9 10.6 7.6 8 5c2.2 2.6 4.4 4.9 6.6 6.8-1.8-1-4.6-2.9-8.1-6 2.3 3.2 4.9 5.8 7.7 7.7-2.5 1.4-6.4 1.6-10.2-.2 2.4 3.6 6 5.9 9.7 5.9 1.8 0 3.4-.5 4.6-1.1.6-.3 1.2.2 1.7.6.3-.6.1-1.9-.4-3.3z"/>' },
    'hand.raised.fill': { f: '<path d="M8.2 11V5.4a1.4 1.4 0 0 1 2.8 0V10h.4V3.9a1.4 1.4 0 0 1 2.8 0V10h.4V5.2a1.4 1.4 0 0 1 2.8 0V11h.3V8.3a1.4 1.4 0 0 1 2.8 0v6c0 4.2-3 7.2-7 7.2-2.6 0-4.3-1-5.8-2.9l-3.2-4a1.5 1.5 0 0 1 2.2-2l1.5 1.5z"/>' },
    'chevron.left.forwardslash.chevron.right': '<path d="M7.5 7l-5 5 5 5M16.5 7l5 5-5 5M14 4.5l-4 15"/>',
    'ladybug.fill': { f: '<path d="M12 7.2c3.7 0 6.3 3 6.3 6.8 0 3.9-2.8 6.6-6.3 6.6s-6.3-2.7-6.3-6.6c0-3.8 2.6-6.8 6.3-6.8z"/><circle cx="12" cy="5.4" r="2.6"/>', s: '<path d="M5.7 11.4L3 10M18.3 11.4L21 10M5.6 15.5H2.8M18.4 15.5h2.8M6.3 18.8L4 20.5M17.7 18.8l2.3 1.7"/>' },
    'cup.and.saucer.fill': { f: '<path d="M4.5 7.5h12v5.3a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5z"/>', s: '<path d="M16.5 9h1.4a2.4 2.4 0 0 1 0 4.8h-1.6M3 20.5h16"/>' },
    'heart.fill': { f: '<path d="M12 20.3l-1.3-1.2C6 14.9 3 12.2 3 8.8 3 6.1 5.1 4 7.8 4c1.5 0 3 .7 4.2 1.9C13.2 4.7 14.7 4 16.2 4 18.9 4 21 6.1 21 8.8c0 3.4-3 6.1-7.7 10.3z"/>' },
    'checkmark.circle.fill': { f: '<path fill-rule="evenodd" d="M12 2.8a9.2 9.2 0 1 1 0 18.4 9.2 9.2 0 0 1 0-18.4zm4.3 6.1a1 1 0 0 0-1.4 0L10.8 13l-1.7-1.7a1 1 0 1 0-1.4 1.4l2.4 2.4a1 1 0 0 0 1.4 0l4.8-4.8a1 1 0 0 0 0-1.4z"/>' },
    'chart.bar.xaxis': '<path d="M3 20.5h18"/><rect x="5" y="11" width="3" height="6.5" rx=".6"/><rect x="10.5" y="5" width="3" height="12.5" rx=".6"/><rect x="16" y="8.5" width="3" height="9" rx=".6"/>',
    'arrow.down.circle': '<circle cx="12" cy="12" r="9.2"/><path d="M12 7.3v9M8.3 12.6l3.7 3.7 3.7-3.7"/>',
    eye: '<path d="M2.5 12S5.8 5.5 12 5.5 21.5 12 21.5 12 18.2 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
    'music.note': { s: '<path d="M10.5 18V5.2l8-1.7v4l-8 1.7"/>', f: '<ellipse cx="7.6" cy="18" rx="3" ry="2.5"/>' },
    'arrow.up.forward.square': '<rect x="3.5" y="3.5" width="17" height="17" rx="3.8"/><path d="M9 15l6-6M10 9h5v5"/>',
    'chevron.right': '<path d="M9 5.5l6.5 6.5L9 18.5"/>',
    checkmark: '<path d="M5 12.6l4.4 4.4L19 7.4"/>',
    'line.3.horizontal': '<path d="M4 7h16M4 12h16M4 17h16"/>',
    'trash.fill': { f: '<path d="M9 3.2h6l.6 1.8H20v1.9H4V5h4.4z"/><path d="M5.5 8.3h13l-1 12.4H6.5z"/>' },
    'trash.slash.fill': { f: '<path d="M9 3.2h6l.6 1.8H20v1.9H4V5h4.4z"/><path d="M5.5 8.3h13l-1 12.4H6.5z"/>', s: '<path d="M3.5 3.5l17 17" stroke-width="2.4"/>' },
    'questionmark.circle.fill': { f: '<circle cx="12" cy="12" r="9.5"/>', k: '<path d="M9.3 9.3a2.8 2.8 0 0 1 5.4 1c0 1.9-2.7 2.4-2.7 4M12 17.3v.1"/>' },
    viewfinder: '<path d="M4 8.5V5.5a1.5 1.5 0 0 1 1.5-1.5h3M15.5 4h3A1.5 1.5 0 0 1 20 5.5v3M20 15.5v3a1.5 1.5 0 0 1-1.5 1.5h-3M8.5 20h-3A1.5 1.5 0 0 1 4 18.5v-3"/>',
    'chevron.up.chevron.down': '<path d="M7.5 9.5L12 5l4.5 4.5M7.5 14.5L12 19l4.5-4.5"/>',
    minus: '<path d="M5 12h14"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    'xmark.circle.fill': { f: '<circle cx="12" cy="12" r="9.2"/>', k: '<path d="M9 9l6 6M15 9l-6 6"/>' },
    'lock.shield.fill': { f: '<path d="M12 2.5l8 3v6.2c0 5.4-3.6 8.7-8 10.3-4.4-1.6-8-4.9-8-10.3V5.5z"/>' },
  };

  function sf(name, size, color = 'currentColor', o = {}) {
    const d = SF[name] || SF['questionmark.circle'];
    const sw = o.w || 1.7;
    const box = `width="${size}" height="${size}" viewBox="0 0 24 24" style="display:block;flex:none${o.style ? ';' + o.style : ''}"`;
    if (typeof d === 'string') return `<svg ${box} fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
    if (d.t) return `<svg ${box}><text x="12" y="16.2" text-anchor="middle" font-family="Inter,system-ui,sans-serif" font-size="11.5" font-weight="700" fill="${color}">${d.t}</text></svg>`;
    return `<svg ${box}>${d.f ? `<g fill="${color}">${d.f}</g>` : ''}${d.s ? `<g fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${d.s}</g>` : ''}${d.k ? `<g fill="none" stroke="${o.knock || 'rgba(0,0,0,.75)'}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">${d.k}</g>` : ''}</svg>`;
  }

  const MARQUEE = size => `<svg width="${size}" height="${size}" viewBox="0 0 512 512" style="display:block;flex:none"><rect x="16" y="16" width="480" height="480" rx="116" fill="#FFCF1A"/><g fill="none" stroke="#1D1D1F" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"><path d="M112 196V128a16 16 0 0 1 16-16h68"/><path d="M400 316v68a16 16 0 0 1-16 16h-68"/></g><rect x="166" y="166" width="124" height="124" rx="20" fill="none" stroke="#1D1D1F" stroke-width="26"/><rect x="222" y="222" width="124" height="124" rx="20" fill="#1D1D1F"/></svg>`;

  const TABS = [
    ['', [['Overview', 'square.grid.2x2']]],
    ['App', [['General', 'gearshape'], ['Shortcuts', 'command']]],
    ['Quitting', [['Automation', 'timer'], ['Advanced', 'slider.horizontal.3'], ['Exclude', 'nosign']]],
    ['Applications', [['Uninstall Apps', 'xmark.app'], ['Leftovers', 'doc.questionmark']]],
    ['Cleanup', [['System Junk', 'gearshape.2'], ['User Cache', 'internaldrive'], ['Mail Files', 'envelope'], ['Trash Bins', 'trash'], ['Large & Old Files', 'clock'], ['AI Apps', 'cpu']]],
    ['Developer Cleanup', [['Xcode Junk', 'hammer'], ['Brew Cache', 'mug'], ['Node Cache', 'leaf'], ['Docker Cache', 'shippingbox']]],
    ['Developer', [['Ports', 'network']]],
    ['QuitX', [['About', 'bolt.fill']]],
    ['More Apps', [['Marquee', 'viewfinder']]],
  ];

  const SUMMARY = {
    Overview: 'Everything QuitX can do. Click a card to jump to its settings.',
    General: 'Startup, sounds, updates, menu bar stats and how QuitX looks.',
    Shortcuts: 'Open QuitX or quit apps from anywhere with your own key combos.',
    Automation: 'Let QuitX quit apps on sleep, after their last window, or when they sit idle.',
    Advanced: 'Background apps, music protection, confirmations and extra list items.',
    Exclude: 'Apps and ports QuitX never quits, manually or automatically.',
    'Uninstall Apps': 'Remove installed apps, support files, caches, preferences and launch items.',
    Leftovers: 'Find files left behind by apps that are no longer installed.',
    'System Junk': 'Review system caches, logs and temporary files.',
    'User Cache': 'Review cache data created by apps in your account.',
    Ports: 'Find and free ports held by dev servers, databases and Docker.',
    About: 'Version, updates and ways to get in touch.',
  };

  const W = 860, H = 600, SIDE_W = 220, PAD = 28, CW = W - SIDE_W - PAD * 2, SCALE = 680 / 860;
  const SIDE_TOP = 38 + 28 + 8 + 1 + 6 + 8;

  function sideShift(tab) {
    let y = 0, target = 0, first = true;
    for (const [g, tabs] of TABS) {
      if (!first) y += 14;
      first = false;
      if (g) y += 14 + 2;
      tabs.forEach(([t], i) => {
        if (t === tab) target = y;
        y += 28 + (i < tabs.length - 1 ? 2 : 0);
      });
    }
    const visible = H - SIDE_TOP - 12 - 8;
    if (target + 28 <= visible) return 0;
    return Math.round(Math.min(y - visible, target - visible / 2));
  }

  function sidebar(tab, shift) {
    const groups = TABS.map(([g, tabs]) => {
      const title = g ? `<div style="padding:0 10px 2px;font-size:10px;font-weight:700;color:${SUB};line-height:12px;text-transform:uppercase">${g}</div>` : '';
      const rows = tabs.map(([t, icon]) => {
        const on = t === tab;
        const glyph = t === 'Marquee' ? MARQUEE(16) : sf(icon, 14, on ? GOLD : SUB, { w: 1.7 });
        return `<div data-tab="${t}" style="display:flex;align-items:center;gap:8px;padding:6px 10px;border-radius:6px;height:28px;box-sizing:border-box;${on ? `background:${AC(0.18)}` : ''}"><span style="width:18px;display:grid;place-items:center">${glyph}</span><span style="font-size:13px;line-height:16px;font-weight:${on ? 500 : 400};color:${INK};white-space:nowrap">${t}</span></div>`;
      }).join('<div style="height:2px"></div>');
      return `<div>${title}${g ? '<div style="height:2px"></div>' : ''}${rows}</div>`;
    }).join('<div style="height:14px"></div>');
    return `<div style="width:${SIDE_W}px;flex:none;background:${SIDE_BG};display:flex;flex-direction:column;position:relative;box-shadow:inset -1px 0 0 rgba(0,0,0,.32)"><div style="padding:38px 10px 8px"><div style="height:28px;border-radius:7px;background:#1E1E1F;box-shadow:inset 0 0 0 .6px ${P(0.11)};display:flex;align-items:center;gap:6px;padding:0 8px">${sf('magnifyingglass', 12, 'rgba(235,235,245,.5)', { w: 2 })}<span style="font-size:12px;color:rgba(235,235,245,.35)">Search settings…</span></div></div><div style="height:1px;background:${P(0.035)}"></div><div style="flex:1;min-height:0;overflow:hidden;padding:14px 8px 0"><div class="sl"${shift ? ` style="transform:translateY(-${shift}px)"` : ''}>${groups}</div></div><div style="height:12px"></div></div>`;
  }

  function settings(o) {
    const shift = o.sideScroll != null ? o.sideScroll : sideShift(o.tab);
    const title = o.tab === 'Marquee' ? 'More Apps' : o.tab;
    const header = `<div style="display:flex;align-items:center;gap:12px;width:${CW}px;flex:none"><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:4px"><div style="font-size:20px;line-height:24px;font-weight:700;color:${INK};letter-spacing:-.01em">${title}</div><div style="font-size:12.5px;line-height:15px;color:${SUB};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${SUMMARY[o.tab] || ''}</div></div>${o.right || ''}</div>`;
    const scrollTo = o.scrollTo ? ` data-scroll-to="${o.scrollTo}"` : '';
    const lights = `<span style="position:absolute;left:14px;top:14px;display:flex;gap:8px;z-index:2"><i style="width:12px;height:12px;border-radius:50%;background:#FF5F57;box-shadow:inset 0 0 0 .5px rgba(0,0,0,.2)"></i><i style="width:12px;height:12px;border-radius:50%;background:#FEBC2E;box-shadow:inset 0 0 0 .5px rgba(0,0,0,.2)"></i><i style="width:12px;height:12px;border-radius:50%;background:#28C840;box-shadow:inset 0 0 0 .5px rgba(0,0,0,.2)"></i></span>`;
    const inner = `<div style="width:${W}px;height:${H}px;zoom:${SCALE};display:flex;position:relative;font-family:'Inter',-apple-system,system-ui,sans-serif;color:${INK};text-align:left;-webkit-font-smoothing:antialiased;letter-spacing:-.005em">${lights}${sidebar(o.tab, shift)}<div style="width:${W - SIDE_W}px;flex:none;box-sizing:border-box;padding:40px ${PAD}px 0;display:flex;flex-direction:column;gap:16px;background:${WIN_BG};position:relative">${header}<div class="qx-page" style="flex:1;min-height:0;overflow:hidden;width:${CW}px"><div class="pane"${scrollTo} style="position:relative;height:100%${o.scroll ? `;transform:translateY(-${o.scroll}px)` : ''}">${o.content}</div></div></div></div>`;
    return `<div class="qx-win qx-settings" style="width:680px;height:474px;border-radius:12px;overflow:hidden;background:${WIN_BG};box-shadow:0 0 0 .5px ${P(0.16)},0 0 0 1px rgba(0,0,0,.6),0 36px 72px rgba(0,0,0,.5),0 6px 18px rgba(0,0,0,.3)">${inner}</div>`;
  }

  const help = `<span style="width:20px;height:20px;display:grid;place-items:center;flex:none">${sf('questionmark.circle', 15, SUB, { w: 1.5 })}</span>`;

  const SECTION_ICON = {
    Startup: 'power', Sounds: 'speaker.wave.2', Updates: 'arrow.triangle.2.circlepath', 'Menu Bar': 'menubar.rectangle', Appearance: 'paintpalette', Sort: 'arrow.up.arrow.down', Default: 'cursorarrow.click.2', Reset: 'arrow.counterclockwise', Sleep: 'moon.zzz', Windows: 'macwindow', Health: 'heart.text.square', 'Auto Quit': 'hourglass', 'Port Killing': 'network', Refresh: 'arrow.clockwise', Discovery: 'dot.radiowaves.left.and.right', 'Group By': 'square.stack.3d.up', Safety: 'checkmark.shield', Selection: 'checklist', Exclude: 'nosign',
  };

  const sectionHeader = (title, symbol) => `<div style="display:flex;align-items:center;gap:9px"><span style="width:24px;height:24px;border-radius:6px;background:${AC(0.12)};display:grid;place-items:center;flex:none">${sf(symbol, 12.5, GOLD, { w: 2 })}</span><span style="font-size:12.5px;font-weight:600;color:${INK};white-space:nowrap">${title}</span><span style="flex:1;height:.5px;background:${P(0.09)}"></span></div>`;

  function srow(label, content, o = {}) {
    const head = label ? `<div style="padding-top:14px">${sectionHeader(label, SECTION_ICON[label] || 'slider.horizontal.3')}</div>` : '';
    const hl = o.hl ? `background:${AC(0.07)};box-shadow:0 0 0 1px ${AC(0.6)};border-radius:10px;` : '';
    return `<div${o.id ? ` id="${o.id}"` : ''}${o.sec ? ` data-sec="${o.sec}"` : ''} style="display:flex;flex-direction:column;gap:7px">${head}<div style="display:flex;align-items:center;gap:10px;min-height:34px;padding:7px 10px 7px 43px;${hl}${o.dim ? 'opacity:.42;' : ''}"><div style="display:flex;align-items:center;gap:10px;min-width:0">${content}</div><span style="flex:1"></span>${o.help === false ? '' : help}</div></div>`;
  }
  const rows = items => `<div style="display:flex;flex-direction:column;gap:5px;width:${CW}px">${items.join('')}</div>`;

  const switchInd = on => `<span class="qx-sw" style="position:relative;width:30px;height:18px;border-radius:9px;flex:none;background:${on ? GOLD : P(0.13)}"><i style="position:absolute;top:2px;left:${on ? 14 : 2}px;width:14px;height:14px;border-radius:50%;background:#fff;box-shadow:0 .5px 1px rgba(0,0,0,.16)"></i></span>`;
  const toggle = (title, on) => `<span style="display:inline-flex;align-items:center;gap:9px;min-height:28px">${switchInd(on)}<span style="font-size:12px;font-weight:500;color:${INK};white-space:nowrap">${title}</span></span>`;

  const RADIO_ICON = { classic: 'rectangle.fill', 'liquid glass': 'drop.fill', icon: 'gauge.with.dots.needle.67percent', text: 'textformat', gb: 'internaldrive', percentage: 'percent', '24-hour': 'clock', '12-hour': 'clock.badge' };
  const radio = (title, sel) => `<span style="display:inline-flex;flex-direction:column;align-items:center;gap:6px;padding:5px;border-radius:10px;background:${P(0.035)};box-shadow:inset 0 0 0 ${sel ? '2px ' + GOLD : '.5px ' + P(0.08)}"><span style="width:70px;height:34px;border-radius:7px;display:grid;place-items:center;background:linear-gradient(135deg,${AC(sel ? 0.23 : 0.1)},${P(0.025)})">${sf(RADIO_ICON[title.toLowerCase()] || 'checkmark', 18, sel ? GOLD : SUB, { w: 2 })}</span><span style="font-size:10.5px;font-weight:${sel ? 600 : 500};color:${sel ? INK : SUB}">${title}</span></span>`;
  const radios = (items, gap = 16) => `<span style="display:inline-flex;gap:${gap}px">${items.map(([t, s]) => radio(t, s)).join('')}</span>`;
  const labeled = (label, inner) => `<span style="display:inline-flex;align-items:center;gap:6px"><span style="width:86px;font-size:11px;color:${INK};flex:none;line-height:13px">${label}</span>${inner}</span>`;

  function tiles(options, sel, width = 500) {
    const cols = Math.max(1, Math.floor((width + 7) / 79));
    const w = (width - 7 * (cols - 1)) / cols;
    return `<span style="display:flex;flex-wrap:wrap;gap:7px;width:${width}px">${options.map(([t, icon]) => {
      const on = t === sel;
      return `<span style="width:${w}px;height:48px;box-sizing:border-box;border-radius:8px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;background:${on ? AC(0.09) : P(0.025)};box-shadow:inset 0 0 0 ${on ? '1.5px ' + GOLD : '.5px ' + P(0.08)}"><span style="height:22px;display:grid;place-items:center">${icon === 'docker' ? dockerIcon(on ? GOLD : SUB) : sf(icon, 15, on ? GOLD : SUB, { w: 2 })}</span><span style="font-size:9.5px;font-weight:${on ? 600 : 500};color:${on ? INK : SUB};white-space:nowrap">${t}</span></span>`;
    }).join('')}</span>`;
  }
  const dockerIcon = c => `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-linecap="round" stroke-linejoin="round" style="display:block"><g stroke-width="1.35"><rect x="3" y="8" width="4" height="4" rx=".7"/><rect x="8" y="8" width="4" height="4" rx=".7"/><rect x="13" y="8" width="4" height="4" rx=".7"/><rect x="8" y="3" width="4" height="4" rx=".7"/><rect x="13" y="3" width="4" height="4" rx=".7"/></g><path stroke-width="1.5" d="M2 13.5h15.5c-.5 5-3 7.5-7 7.5-4.5 0-7.5-3-8.5-7.5zM17.2 13.5c2.1-.2 3.5-1.5 4.3-4M19.2 10.8l-.7-3.3 3 2 1.5-2.5"/></svg>`;

  const button = (label, o = {}) => `<span style="display:inline-flex;align-items:center;gap:5px;height:20px;padding:0 9px;border-radius:5px;font-size:11.5px;font-weight:500;white-space:nowrap;${o.prominent ? `background:linear-gradient(${GOLD},#F5AE1C);color:#fff;box-shadow:inset 0 .5px 0 rgba(255,255,255,.25),0 .5px 1px rgba(0,0,0,.25)` : `background:${P(0.13)};color:${INK};box-shadow:inset 0 .5px 0 ${P(0.08)},0 .5px 1px rgba(0,0,0,.25)`}">${o.icon ? sf(o.icon, 11, 'currentColor', { w: 2.2 }) : ''}${label}</span>`;

  const popup = (label, o = {}) => `<span style="${o.flex ? 'flex:1;min-width:0;' : ''}${o.width ? `width:${o.width}px;` : ''}display:inline-flex;align-items:center;height:20px;border-radius:5px;background:${P(0.13)};box-shadow:inset 0 .5px 0 ${P(0.08)},0 .5px 1px rgba(0,0,0,.25);padding:0 2px 0 8px;box-sizing:border-box;gap:6px"><span style="flex:1;min-width:0;font-size:11.5px;color:${INK};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${label}</span><span style="width:16px;height:16px;border-radius:4px;background:${GOLD};display:grid;place-items:center;flex:none">${sf('chevron.up.chevron.down', 11, '#fff', { w: 2.6 })}</span></span>`;
  const menuChrome = (label, width) => `<span style="display:inline-flex;align-items:center;height:30px;padding:0 5px;border-radius:8px;background:${P(0.045)};box-shadow:inset 0 0 0 .5px ${P(0.09)};width:${width}px;box-sizing:border-box">${popup(label, { flex: true })}</span>`;
  const stepper = () => `<span style="display:inline-flex;flex-direction:column;width:13px;height:22px;border-radius:4px;background:${P(0.13)};box-shadow:inset 0 .5px 0 ${P(0.08)},0 .5px 1px rgba(0,0,0,.25);overflow:hidden"><span style="flex:1;display:grid;place-items:center;border-bottom:.5px solid rgba(0,0,0,.3)"><svg width="7" height="4" viewBox="0 0 7 4"><path d="M.8 3.4L3.5.8l2.7 2.6" fill="none" stroke="${INK}" stroke-width="1.2"/></svg></span><span style="flex:1;display:grid;place-items:center"><svg width="7" height="4" viewBox="0 0 7 4"><path d="M.8.6l2.7 2.6L6.2.6" fill="none" stroke="${INK}" stroke-width="1.2"/></svg></span></span>`;
  const t11 = s => `<span style="font-size:11px;color:${INK};white-space:nowrap">${s}</span>`;

  const STAT_TITLES = { cpu: 'CPU', gpu: 'GPU', mem: 'Memory', bat: 'Battery', clean: 'Cleanup' };
  function statChips(order, on, dragging) {
    return `<span style="display:flex;flex-wrap:wrap;gap:5px;max-width:500px">${order.map(k => `<span data-chip="${k}" style="display:inline-flex;align-items:center;gap:5px;height:28px;padding:0 8px 0 6px;border-radius:7px;background:${P(dragging === k ? 0.1 : 0.045)};box-shadow:inset 0 0 0 1px ${dragging === k ? AC(0.8) : P(0.08)}">${sf('line.3.horizontal', 9, 'rgba(235,235,245,.42)', { w: 3 })}${switchInd(on[k] !== false)}<span style="font-size:11px;font-weight:500;color:${INK}">${STAT_TITLES[k]}</span></span>`).join('')}</span>`;
  }

  const REFRESH = [['1 sec', 'hare'], ['2 sec', 'speedometer'], ['3 sec', 'speedometer'], ['5 sec', 'gauge.with.dots.needle.50percent'], ['10 sec', 'tortoise']];

  function general(o = {}) {
    const order = o.order || ['cpu', 'gpu', 'mem', 'bat', 'clean'];
    return rows([
      srow('Startup', toggle('Open QuitX at login', true), { sec: 'startup' }),
      srow('Sounds', toggle('Play cool sounds', true), { hl: o.hl === 'sounds', sec: 'sounds' }),
      srow('Updates', toggle('Check for updates automatically', true), { sec: 'updates' }),
      srow('', toggle('Download and prepare updates automatically', true)),
      srow('Menu Bar', toggle('Show stats in menu bar', true), { hl: o.hl === 'stats', sec: 'menubar' }),
      srow('', statChips(order, o.on || {}, o.dragging), { hl: o.hl === 'stats' }),
      srow('', labeled('Style format', radios([['Icon', true], ['Text', false]])), { help: false }),
      srow('', labeled('Memory format', radios([['GB', true], ['Percentage', false]])), { help: false }),
      srow('', labeled('Refresh', tiles(REFRESH, '1 sec', 390)), { hl: o.hl === 'stats' }),
      srow('', labeled('Cleanup scan', tiles([['Always', 'bolt'], ['1 min', 'clock'], ['5 min', 'clock'], ['15 min', 'clock']], '1 min', 390))),
      srow('', labeled('Background scan', tiles([['5 min', 'speedometer'], ['10 min', 'speedometer'], ['30 min', 'tortoise'], ['1 hr', 'tortoise']], '10 min', 390))),
      srow('Appearance', radios([['Classic', o.glass === false], ['Liquid Glass', o.glass !== false]], 18), { hl: o.hl === 'theme', sec: 'appearance' }),
      srow('Sort', tiles([['CPU High', 'arrow.down.right.circle'], ['CPU Low', 'arrow.up.right.circle'], ['Memory High', 'arrow.down.right.circle'], ['Memory Low', 'arrow.up.right.circle'], ['A–Z', 'textformat.abc'], ['Z–A', 'textformat.abc']], 'A–Z')),
      srow('Default', tiles([['Normal Quit', 'power'], ['Force Quit', 'bolt.fill']], 'Normal Quit')),
      srow('Reset', button('Reset All Settings', { icon: 'arrow.counterclockwise' })),
    ]);
  }

  function automation(o = {}) {
    const on = !!o.sleep;
    const time = (h, m) => `<span style="display:inline-flex;align-items:center;gap:4px">${menuChrome(h, 58)}<span style="font-size:11px;font-weight:500;color:${INK}">:</span>${menuChrome(m, 62)}</span>`;
    return rows([
      srow('Sleep', toggle('Quit apps after Mac sleeps', on), { id: 'r-sleep', hl: o.hl === 'sleep', sec: 'sleep' }),
      srow('', labeled('Time format', radios([['24-hour', true], ['12-hour', false]])), { dim: !on, help: false }),
      srow('', labeled('From:', time('00', '00')), { dim: !on, help: false }),
      srow('', labeled('To:', time('06', '00')), { dim: !on, help: false }),
      srow('Windows', toggle('Quit app when its last window closes', true)),
      srow('', `<span style="display:inline-flex;align-items:center;gap:10px"><span style="display:inline-flex;align-items:center;gap:5px;font-size:11px;color:${SUB}">${sf('checkmark.circle.fill', 13, SUB)}Accessibility allowed</span>${button('Remove Accessibility')}</span>`, { help: false }),
      srow('Health', toggle('Warn & rescue CPU hogs', true)),
      srow('', `<span style="display:inline-flex;align-items:center;gap:6px">${t11('CPU over')}${t11('90')}${stepper()}${t11('%')}</span>`, { help: false }),
      srow('', toggle('Rescue on memory pressure', false)),
      srow('', `<span style="display:inline-flex;align-items:center;gap:6px">${t11('Memory over')}${t11('12')}${stepper()}${t11('GB of 16')}</span>`, { dim: true, help: false }),
      srow('Auto Quit', toggle('Quit inactive apps after', false)),
      srow('', `<span style="display:inline-flex;align-items:center;gap:6px">${t11('1')}${stepper()}${menuChrome('hours', 90)}</span>`, { dim: true, help: false }),
    ]);
  }

  function portSettings(o = {}) {
    const dim = o.enabled === false;
    return rows([
      srow('Port Killing', toggle('Enable port killing', !dim), { hl: o.hl === 'enable' }),
      srow('Refresh', tiles(REFRESH, '3 sec', 390), { dim }),
      srow('Discovery', toggle('Include UDP listeners', false), { dim }),
      srow('Group By', tiles([['None', 'list.bullet'], ['Project', 'folder'], ['Docker', 'docker'], ['Process', 'arrow.triangle.branch']], 'None', 390), { dim }),
      srow('Sort', tiles([['Port Low', 'arrow.up'], ['Port High', 'arrow.down'], ['Name', 'textformat.abc'], ['Memory', 'memorychip'], ['CPU', 'cpu']], 'Port Low'), { dim }),
      srow('Default', tiles([['Kill', 'power'], ['Force Kill', 'bolt.fill']], 'Kill'), { dim }),
      srow('Safety', toggle('Confirm before killing ports', true), { dim }),
      srow('Selection', toggle('Select all ports by default', false), { dim }),
      srow('Exclude', button('Manage Excluded Ports…', { icon: 'nosign' }), { dim }),
    ]);
  }

  const TINT = { general: '#408FFA', shortcuts: '#8C6BF5', automation: '#FA9433', advanced: '#ED5C8F', exclude: '#F0544F', ports: '#29B5A3' };

  function thumb(symbol, tint, status, symbolColor = '#fff') {
    const active = status && !['Off', 'Empty'].includes(status);
    const rgb = hexRgb(tint);
    const pill = status ? `<span style="position:absolute;top:7px;right:7px;font-size:9.5px;font-weight:600;padding:2px 6px;border-radius:99px;line-height:12px;${active ? `background:${GOLD};color:rgba(0,0,0,.82)` : `background:${P(0.08)};color:${SUB}`}">${status}</span>` : '';
    return `<div style="position:relative;height:74px;border-radius:8px;overflow:hidden;display:grid;place-items:center;background:linear-gradient(135deg,rgba(${rgb},.30),rgba(${rgb},.07))"><span style="position:absolute;left:50%;top:50%;width:96px;height:96px;margin:-48px 0 0 -48px;border-radius:50%;background:radial-gradient(closest-side,rgba(${rgb},.42) 8%,rgba(${rgb},0))"></span><span style="position:relative;width:38px;height:38px;border-radius:10px;display:grid;place-items:center;background:linear-gradient(rgba(${rgb},.95),rgba(${rgb},.75));box-shadow:0 3px 6px rgba(${rgb},.35)">${sf(symbol, 19, symbolColor, { w: 2.1, knock: tint })}</span>${pill}</div>`;
  }
  function hexRgb(h) {
    const n = parseInt(h.slice(1), 16);
    return `${(n >> 16) & 255},${(n >> 8) & 255},${n & 255}`;
  }
  const featureCard = (symbol, tint, title, detail, status, footer) => `<div style="padding:8px;border-radius:11px;background:${P(0.035)};box-shadow:inset 0 0 0 .5px ${P(0.09)};display:flex;flex-direction:column;gap:9px;box-sizing:border-box;min-width:0">${thumb(symbol, tint, status)}<div style="padding:0 3px;display:flex;flex-direction:column;gap:3px"><div style="font-size:12.5px;font-weight:600;color:${INK};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${title}</div><div style="font-size:11px;line-height:14px;color:${SUB};min-height:28px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden">${detail}</div>${footer ? `<div style="display:flex;align-items:center;gap:3px;padding-top:3px;font-size:10.5px;font-weight:500;color:rgba(235,235,245,.48)">${footer}${sf('chevron.right', 9, 'currentColor', { w: 3 })}</div>` : ''}</div></div>`;
  const grid3 = cards => `<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">${cards.join('')}</div>`;
  const groupTitle = t => `<div style="font-size:10px;font-weight:700;color:${SUB};line-height:12px">${t}</div>`;

  const FEATURES = [
    ['APP', [
      ['power.circle', 'general', 'Open at Login', 'Start QuitX quietly every time you log in.', 'On', 'General'],
      ['chart.bar.xaxis', 'general', 'Menu Bar Stats', 'Live CPU, memory, GPU and battery right in the menu bar.', 'On', 'General'],
      ['paintpalette', 'general', 'Appearance', 'Solid Classic or translucent Liquid Glass on macOS 26.', 'Classic', 'General'],
      ['speaker.wave.2', 'general', 'Sounds', 'A short arcade laser every time an app goes.', 'On', 'General'],
      ['arrow.down.circle', 'general', 'Updates', 'New versions straight from GitHub, verified before install.', 'On', 'General'],
      ['bolt.fill', 'general', 'Quit or Force Quit', 'Quit politely by default, or make Force Quit the default.', 'Normal', 'General'],
      ['command', 'shortcuts', 'Global Shortcuts', 'Open QuitX, Quit All or Force Quit All from anywhere.', '1 on', 'Shortcuts'],
    ]],
    ['QUITTING', [
      ['moon.zzz', 'automation', 'Quit on Sleep', 'Close apps left open when your Mac wakes from sleep in the hours you pick.', 'On', 'Automation'],
      ['macwindow', 'automation', 'Last Window Closes', 'Quit an app as soon as you close its last window.', 'On', 'Automation'],
      ['gauge.with.dots.needle.67percent', 'automation', 'CPU & Memory Rescue', 'Get a heads-up when CPU or memory stays too high.', 'On', 'Automation'],
      ['hourglass', 'automation', 'Auto Quit', "Quit apps you haven't touched in a while.", 'Off', 'Automation'],
      ['eye', 'advanced', 'Background Apps', 'Show helpers and agents that never appear in the Dock.', 'Off', 'Advanced'],
      ['music.note', 'advanced', 'Music Protection', 'Keep music playing through every quit.', 'On', 'Advanced'],
    ]],
  ];

  function overview() {
    const sections = FEATURES.map(([g, list]) => `<div style="display:flex;flex-direction:column;gap:10px">${groupTitle(g)}${grid3(list.map(([s, t, ti, d, st, f]) => featureCard(s, TINT[t], ti, d, st, f)))}</div>`).join('');
    return `<div style="display:flex;flex-direction:column;gap:22px;width:${CW}px">${sections}</div>`;
  }

  function aboutTab() {
    const hl = (symbol, title, detail) => `<div style="flex:1;display:flex;align-items:flex-start;gap:9px;min-width:0"><span style="width:28px;height:28px;border-radius:7px;background:${AC(0.1)};display:grid;place-items:center;flex:none">${sf(symbol, 14, GOLD, { w: 2 })}</span><div style="display:flex;flex-direction:column;gap:2px;min-width:0"><div style="font-size:11.5px;font-weight:600;color:${INK}">${title}</div><div style="font-size:10.5px;line-height:13px;color:${SUB}">${detail}</div></div></div>`;
    const hero = `<div style="display:flex;align-items:center;gap:16px;padding:14px;border-radius:14px;background:linear-gradient(135deg,${AC(0.12)},${P(0.035)});box-shadow:inset 0 0 0 .5px ${P(0.08)}"><img src="${A}icon.png" style="width:72px;height:72px;display:block;flex:none" alt=""><div style="display:flex;flex-direction:column;gap:5px;flex:1;min-width:0"><div style="display:flex;align-items:center;gap:8px"><span style="font-size:21px;font-weight:700;color:${INK};letter-spacing:-.01em">QuitX</span><span style="font-size:9px;font-weight:700;color:${GOLD};padding:3px 7px;border-radius:99px;background:${AC(0.11)};letter-spacing:.02em">VERSION 1.2.3</span></div><div style="font-size:12.5px;font-weight:500;color:${INK}">Quit everything. Keep what matters.</div><div style="display:flex;align-items:center;gap:5px">${sf('checkmark.circle.fill', 11, '#32D74B')}<span style="font-size:10.5px;color:${SUB}">Up to date</span></div></div>${button('Check for Updates', { prominent: true })}</div>`;
    const why = `<div style="display:flex;flex-direction:column;gap:10px">${sectionHeader('Why QuitX', 'sparkles')}<div style="display:flex;gap:18px;padding-left:33px">${hl('swift', 'Native', 'Fast SwiftUI app with a small footprint.')}${hl('hand.raised.fill', 'Private', 'No account, tracking or analytics.')}${hl('chevron.left.forwardslash.chevron.right', 'Open Source', 'Free forever under the MIT license.')}</div></div>`;
    const res = `<div style="display:flex;flex-direction:column;gap:10px">${sectionHeader('Resources', 'lifepreserver')}<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;padding-left:33px">${featureCard('ladybug.fill', '#F0615C', 'Report an Issue', 'Share feedback or a bug.', null, 'Open GitHub')}${featureCard('cup.and.saucer.fill', GOLD, 'Buy Me a Coffee', 'Support independent development.', null, 'Open Buy Me a Coffee')}</div></div>`;
    const link = '#419CFF';
    const foot = `<div style="display:flex;align-items:center;gap:7px;font-size:10.5px;color:${SUB}">${sf('heart.fill', 11, GOLD)}<span>Designed and built by</span><span style="color:${link}">Toufiq Hasan Kiron</span><span style="color:rgba(235,235,245,.36)">•</span><span style="color:${link}">GitHub</span></div>`;
    return `<div style="display:flex;flex-direction:column;gap:16px;padding-top:14px;width:${CW}px;min-height:470px;box-sizing:border-box">${hero}${why}${res}<div style="flex:1;min-height:8px"></div>${foot}</div>`;
  }

  const scanHead = (size, count) => `<div style="display:flex;align-items:center;gap:12px;flex:none"><div style="text-align:right;display:flex;flex-direction:column;gap:2px"><div style="font-size:14px;font-weight:600;color:${INK};font-variant-numeric:tabular-nums">${size}</div><div style="font-size:10px;color:${SUB}">${count}</div></div>${primaryBtn('Scan Again')}</div>`;
  const primaryBtn = (label, on = true) => `<span style="display:inline-flex;align-items:center;gap:6px;height:28px;padding:0 14px;border-radius:6px;font-size:12px;font-weight:700;white-space:nowrap;font-variant-numeric:tabular-nums;${on ? `background:linear-gradient(${GOLD},${GOLD2});color:rgba(0,0,0,.88);box-shadow:0 1px 2px ${AC(0.18)}` : `background:${P(0.08)};color:${P(0.35)}`}">${label}</span>`;
  const dangerBtn = (label, on = true) => `<span style="display:inline-flex;align-items:center;gap:6px;height:28px;padding:0 14px;border-radius:6px;font-size:12px;font-weight:700;white-space:nowrap;font-variant-numeric:tabular-nums;${on ? 'background:linear-gradient(#FF453A,#D22828);color:#fff;box-shadow:0 1px 2px rgba(255,69,58,.18)' : `background:${P(0.08)};color:${P(0.35)}`}">${on ? sf('trash.fill', 12, '#fff') : ''}${label}</span>`;
  const secondaryBtn = (label, enabled = true) => `<span style="display:inline-flex;align-items:center;height:28px;padding:0 12px;border-radius:6px;font-size:12px;font-weight:500;white-space:nowrap;background:${P(0.07)};box-shadow:inset 0 0 0 .5px ${P(enabled ? 0.12 : 0.06)};color:${P(enabled ? 0.85 : 0.3)}">${label}</span>`;
  const checkbox = on => `<span style="width:14px;height:14px;border-radius:3px;flex:none;display:grid;place-items:center;background:${on ? GOLD : P(0.08)}">${on ? sf('checkmark', 10, 'rgba(0,0,0,.9)', { w: 3.4 }) : ''}</span>`;
  const footerBar = (selAll, deselAll, primary) => `<div style="flex:none"><div style="height:1px;background:${P(0.1)}"></div><div style="display:flex;align-items:center;gap:8px;padding:12px 0">${secondaryBtn('Select All', selAll)}${secondaryBtn('Deselect All', deselAll)}<span style="flex:1"></span>${primary}</div></div>`;
  const searchField = (text, glass) => `<div style="flex:1;height:28px;border-radius:7px;display:flex;align-items:center;gap:6px;padding:0 8px;box-sizing:border-box;${glass ? `background:#1E1E1F;box-shadow:inset 0 0 0 .6px ${P(0.11)}` : `background:${P(0.045)};box-shadow:inset 0 0 0 .5px ${P(0.08)}`}">${sf('magnifyingglass', 12, SUB, { w: 2 })}<span style="font-size:${glass ? 12 : 11.5}px;color:rgba(235,235,245,.35)">${text}</span></div>`;
  const smallTag = t => `<span style="font-size:9px;font-weight:600;color:${SUB};padding:1px 5px;border-radius:3px;background:${P(0.08)};line-height:11px">${t}</span>`;

  const UNINSTALL_APPS = [
    { n: 'Discord', i: 'discord', id: 'com.hnc.Discord', size: '412 MB', tags: ['Running'] },
    { n: 'Google Chrome', i: 'chrome', id: 'com.google.Chrome', size: '1.31 GB', tags: ['Running'] },
    { n: 'Maps', i: 'maps', id: 'com.apple.Maps', size: '96 MB', tags: [] },
    { n: 'Telegram', i: 'telegram', id: 'ru.keepcoder.Telegram', size: '284 MB', tags: ['Running', 'Menu Bar'] },
    { n: 'Visual Studio Code', i: 'vscode', id: 'com.microsoft.VSCode', size: '604 MB', tags: [] },
  ];

  function uninstallTab(o = {}) {
    const sel = new Set(o.selected || []);
    const layout = `<span style="display:inline-flex;gap:2px;padding:2px;border-radius:7px;background:${P(0.05)};box-shadow:inset 0 0 0 .5px ${P(0.08)}"><span style="width:26px;height:24px;border-radius:5px;background:${P(0.12)};display:grid;place-items:center">${sf('list.bullet', 13, INK, { w: 2 })}</span><span style="width:26px;height:24px;border-radius:5px;display:grid;place-items:center">${sf('square.grid.2x2', 13, SUB, { w: 1.9 })}</span></span>`;
    const list = UNINSTALL_APPS.map(a => {
      const on = sel.has(a.n);
      return `<div data-app="${a.n}" style="display:flex;align-items:center;gap:10px;padding:6px 8px;border-radius:6px;${on ? `background:${AC(0.1)}` : ''}">${checkbox(on)}<img src="${A}icons/${a.i}.png" style="width:24px;height:24px;display:block;flex:none" alt=""><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:1px"><div style="display:flex;align-items:center;gap:6px"><span style="font-size:12.5px;font-weight:500;color:${INK}">${a.n}</span>${a.tags.map(smallTag).join('')}</div><span style="font-size:10px;color:${SUB}">${a.id}</span></div><span style="font-size:11px;color:${SUB};font-variant-numeric:tabular-nums">${a.size}</span></div>`;
    }).join('');
    const count = sel.size;
    const primary = primaryBtn(count ? `Review ${count} ${count === 1 ? 'App' : 'Apps'} (${o.selectedSize})` : 'Choose Apps to Uninstall', count > 0);
    return `<div style="display:flex;flex-direction:column;height:100%;width:${CW}px"><div style="display:flex;align-items:center;gap:8px;padding-bottom:8px">${searchField('Search apps', true)}${layout}</div><div style="display:flex;gap:8px;padding-bottom:6px">${popup('All apps', { flex: true })}${popup('Any size', { flex: true })}${popup('Name (A–Z)', { flex: true })}</div><div style="font-size:10.5px;color:${SUB};padding-bottom:8px">${UNINSTALL_APPS.length} of ${UNINSTALL_APPS.length} apps shown</div><div style="flex:1;min-height:0;overflow:hidden">${list}</div>${footerBar(count < UNINSTALL_APPS.length, count > 0, primary)}</div>`;
  }

  function filesTab(o = {}) {
    const items = o.items || [];
    const sel = new Set(o.selected || items.map(it => it.path));
    const tint = o.tint || (items === LEFTOVERS ? '#FF9F0A' : '#0A84FF');
    const list = items.map(it => `<div style="display:flex;align-items:center;gap:10px;padding:8px 0">${checkbox(sel.has(it.path))}<span style="width:22px;display:grid;place-items:center;flex:none">${sf(it.dir ? 'folder.fill' : 'doc.fill', 16, it.dir ? tint : SUB)}</span><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:2px"><div style="display:flex;align-items:center;gap:6px;min-width:0"><span style="font-size:12.5px;font-weight:500;color:${INK};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${it.n}</span>${it.tag ? `<span style="font-size:8.5px;font-weight:600;color:${SUB};padding:1.5px 5px;border-radius:99px;background:${P(0.07)};white-space:nowrap">${it.tag}</span>` : ''}</div><span style="font-size:10px;color:${SUB};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${it.path}</span></div><span style="width:80px;text-align:right;font-size:10.5px;color:${SUB};flex:none">${it.date || '28 Oct 2026'}</span><span style="min-width:62px;text-align:right;font-size:11px;font-weight:500;color:${SUB};font-variant-numeric:tabular-nums;flex:none">${it.size}</span><span style="width:24px;height:24px;display:grid;place-items:center;flex:none">${sf('arrow.up.forward.square', 14, SUB, { w: 1.7 })}</span></div><div style="height:1px;background:${P(0.08)};margin-left:54px"></div>`).join('');
    const count = items.filter(it => sel.has(it.path)).length;
    const filter = `<div style="display:flex;flex-direction:column;gap:8px;padding:4px 0">${searchField('Search name or path…')}<div style="display:flex;gap:8px">${popup('Any size', { flex: true })}${popup('Any age', { flex: true })}${popup('Largest first', { flex: true })}</div><div style="font-size:10.5px;color:${SUB}">${items.length} of ${items.length} items shown</div></div>`;
    return `<div style="display:flex;flex-direction:column;height:100%;width:${CW}px"><div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:6px">${filter}<div style="flex:1;min-height:0;overflow:hidden">${list}</div></div>${footerBar(count < items.length, count > 0, dangerBtn(count ? `Delete ${count} (${o.selectedSize})` : 'Delete Permanently', count > 0))}</div>`;
  }

  const LEFTOVERS = [
    { n: 'com.example.oldapp', path: '~/Library/Application Support/com.example.oldapp', size: '186 MB', dir: true, tag: 'Application Support' },
    { n: 'com.example.oldapp', path: '~/Library/Caches/com.example.oldapp', size: '42.1 MB', dir: true, tag: 'Caches' },
    { n: 'com.example.oldapp.plist', path: '~/Library/Preferences/com.example.oldapp.plist', size: '8 KB', tag: 'Preferences' },
    { n: 'com.example.oldapp.savedState', path: '~/Library/Saved Application State/com.example.oldapp.savedState', size: '24 KB', dir: true, tag: 'Saved State' },
  ];
  const CACHES = [
    { n: 'Google', path: '~/Library/Caches/Google', size: '1.92 GB', dir: true },
    { n: 'com.spotify.client', path: '~/Library/Caches/com.spotify.client', size: '684 MB', dir: true },
    { n: 'com.tinyspeck.slackmacgap', path: '~/Library/Caches/com.tinyspeck.slackmacgap', size: '312 MB', dir: true },
    { n: 'com.apple.Safari', path: '~/Library/Caches/com.apple.Safari', size: '96.4 MB', dir: true },
    { n: 'com.apple.siri.bundleservicecache.plist', path: '~/Library/Caches/com.apple.siri.bundleservicecache.plist', size: '12 KB' },
  ];

  function fitAll(root) {
    (root || document).querySelectorAll('[data-scroll-to]').forEach(p => {
      const t = p.querySelector(`[data-sec="${p.dataset.scrollTo}"]`);
      if (!t) return;
      const page = p.parentElement;
      const max = Math.max(0, p.scrollHeight - page.clientHeight);
      p.style.transform = `translateY(-${Math.min(max, t.offsetTop)}px)`;
    });
    (root || document).querySelectorAll('.qx-chrome').forEach(fitChrome);
  }

  function shapePath(w, h, ax) {
    const top = 12, r = 14, hw = 16;
    const x = Math.max(r + hw, Math.min(ax, w - r - hw));
    const f = n => +n.toFixed(2);
    return `M${r} ${top}H${f(x - hw)}C${f(x - 14)} ${top} ${f(x - 12)} ${top - 0.9} ${f(x - 10.4)} ${top - 2.4}L${f(x - 4)} ${top - 9.2}C${f(x - 1.8)} ${top - 11.8} ${f(x + 1.8)} ${top - 11.8} ${f(x + 4)} ${top - 9.2}L${f(x + 10.4)} ${top - 2.4}C${f(x + 12)} ${top - 0.9} ${f(x + 14)} ${top} ${f(x + hw)} ${top}H${w - r}A${r} ${r} 0 0 1 ${w} ${top + r}V${h - r}A${r} ${r} 0 0 1 ${w - r} ${h}H${r}A${r} ${r} 0 0 1 0 ${h - r}V${top + r}A${r} ${r} 0 0 1 ${r} ${top}Z`;
  }

  let chromeSeq = 0;
  function chrome(ax, glass) {
    const g = glass === true ? 1 : (+glass || 0);
    const id = `qxc${++chromeSeq}`;
    return `<div class="qx-chrome" data-ax="${ax}" style="position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none;z-index:0"><svg class="qx-shadow" style="position:absolute;left:0;top:0;overflow:visible" width="0" height="0"><defs><filter id="${id}f" x="-50%" y="-50%" width="200%" height="200%"><feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#000" flood-opacity=".5"/><feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#000" flood-opacity=".3"/></filter><mask id="${id}m" maskUnits="userSpaceOnUse" x="-200" y="-200" width="2000" height="2000"><rect x="-200" y="-200" width="2000" height="2000" fill="#fff"/><path class="d" fill="#000"/></mask></defs><g mask="url(#${id}m)"><path class="d" fill="#000" filter="url(#${id}f)"/></g></svg><div class="qx-layer" style="position:absolute;inset:0;background:var(--qx-panel);opacity:${1 - g}"></div><div class="qx-layer" style="position:absolute;inset:0;opacity:${g};background:linear-gradient(160deg,rgba(255,255,255,.16),rgba(255,255,255,0) 28%,rgba(255,255,255,0) 72%,rgba(255,255,255,.08)),rgba(48,44,42,.42);-webkit-backdrop-filter:blur(22px) saturate(1.8);backdrop-filter:blur(22px) saturate(1.8)"></div><svg class="qx-stroke" style="position:absolute;left:0;top:0;overflow:visible" width="0" height="0"><path class="d" fill="none" stroke="rgba(255,255,255,.14)" stroke-width="1" opacity="${1 - g}"/><path class="d" fill="none" stroke="rgba(255,255,255,.26)" stroke-width="1" opacity="${g}"/></svg></div>`;
  }

  function fitChrome(el) {
    const w = el.offsetWidth, h = el.offsetHeight;
    if (!w || !h) return;
    const key = `${w}x${h}x${el.dataset.ax}`;
    if (el.dataset.fit === key) return;
    el.dataset.fit = key;
    const d = shapePath(w, h, +el.dataset.ax);
    el.querySelectorAll('svg').forEach(s => { s.setAttribute('width', w); s.setAttribute('height', h); });
    el.querySelectorAll('path.d').forEach(p => p.setAttribute('d', d));
    el.querySelectorAll('.qx-layer').forEach(l => { l.style.clipPath = `path('${d}')`; });
  }

  if (typeof MutationObserver !== 'undefined') {
    const mo = new MutationObserver(() => fitAll());
    const start = () => { mo.observe(document.body, { childList: true, subtree: true }); fitAll(); };
    if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
  }

  const SD = {
    red: '#F0454D', blue: '#218CF2', chart: '#268CFA', orange: '#FF9E26', pink: '#FA4D73',
    gray: 'rgba(255,255,255,.25)', yellow: '#FACC33', green: '#33B859', gold: '#FEBC33',
    ink: 'rgba(255,255,255,.92)', sub: 'rgba(235,235,245,.6)',
  };
  const hsb = (h, sat, v) => {
    const f = n => { const k = (n + h * 6) % 6; return v - v * sat * Math.max(0, Math.min(k, 4 - k, 1)); };
    return `rgb(${Math.round(f(5) * 255)},${Math.round(f(3) * 255)},${Math.round(f(1) * 255)})`;
  };
  const levelColor = i => hsb((0.56 + i * 0.61803398875) % 1, 0.72, 0.92);
  const sdIcons = {
    cpu: '<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="3.5" width="9" height="9" rx="1.6"/><rect x="6" y="6" width="4" height="4" rx=".6" fill="currentColor"/><path d="M6 1.5v2M10 1.5v2M6 12.5v2M10 12.5v2M1.5 6h2M1.5 10h2M12.5 6h2M12.5 10h2"/></svg>',
    memory: '<svg width="12" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="1.5" y="4.5" width="13" height="6.5" rx="1"/><path d="M4 7v1.5M6.5 7v1.5M9 7v1.5M11.5 7v1.5M3 11v2M6 11v2M10 11v2M13 11v2"/></svg>',
    gpu: '<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M8 1.6l5.6 3.2v6.4L8 14.4 2.4 11.2V4.8z"/><path d="M2.4 4.8L8 8l5.6-3.2M8 8v6.4"/></svg>',
    sparkles: '<svg width="11" height="11" viewBox="0 0 16 16" fill="currentColor"><path d="M7 1.2l1.4 3.9 3.9 1.4-3.9 1.4L7 11.8 5.6 7.9 1.7 6.5l3.9-1.4z"/><path d="M12.4 9.4l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"/></svg>',
    sliders: '<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M2 4h12M2 8h12M2 12h12"/><circle cx="5" cy="4" r="1.6" fill="#2B2A2D"/><circle cx="11" cy="8" r="1.6" fill="#2B2A2D"/><circle cx="7" cy="12" r="1.6" fill="#2B2A2D"/></svg>',
    trash: '<svg width="11" height="11" viewBox="0 0 16 16" fill="currentColor"><path d="M5.5 1.5h5l.5 1.3H14v1.4H2V2.8h3z"/><path d="M3.2 5h9.6l-.8 9.5H4z"/></svg>',
    battery: '<svg width="13" height="9" viewBox="0 0 22 12"><rect x="1" y="1.5" width="17" height="9" rx="2.6" fill="currentColor"/><path d="M19.6 4.6v2.8c.7-.2 1.1-.8 1.1-1.4s-.4-1.2-1.1-1.4z" fill="currentColor"/></svg>',
    activity: '<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M2.6 11.5a6 6 0 1 1 10.8 0"/><path d="M8 9.2l2.6-3"/><circle cx="8" cy="9.4" r="1" fill="currentColor"/></svg>',
    wave: '<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M1.5 8.5h3l1.5-4 3 8 1.6-4.5h3.9"/></svg>',
    batteryBlock: '<svg width="12" height="10" viewBox="0 0 16 14" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="1.5" y="3" width="13" height="9.5" rx="2"/><path d="M4.5 1.2v1.8M11.5 1.2v1.8"/></svg>',
    out: '<svg width="8" height="8" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7l4.2-4.2M3.6 2.8h3.6v3.6"/></svg>',
  };
  const sdRing = (segments, text, size, lw, fontScale = 0.22) => {
    const r = (size - lw) / 2, c = 2 * Math.PI * r;
    let acc = 0;
    const arcs = segments.map(([frac, color]) => {
      const len = Math.max(0, Math.min(1, frac)) * c;
      const el = `<circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${color}" stroke-width="${lw}" stroke-dasharray="${len} ${c}" stroke-dashoffset="${-acc}" transform="rotate(-90 ${size / 2} ${size / 2})"/>`;
      acc += len;
      return el;
    }).join('');
    return `<div style="position:relative;width:${size}px;height:${size}px;flex:none"><svg width="${size}" height="${size}" style="display:block"><circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${SD.gray}" stroke-width="${lw}"/>${arcs}</svg><div style="position:absolute;inset:0;display:grid;place-items:center;font-size:${(size * fontScale).toFixed(1)}px;font-weight:600;color:${SD.ink};font-variant-numeric:tabular-nums">${text}</div></div>`;
  };
  const sdCard = (inner, extra = '') => `<div style="padding:8px 9px;border-radius:7px;background:rgba(255,255,255,.035);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.08);${extra}">${inner}</div>`;
  const sdSection = (title, inner) => `<div style="display:flex;flex-direction:column;gap:5px"><div style="padding:0 2px;font-size:9.5px;font-weight:700;letter-spacing:.6px;text-transform:uppercase;color:${SD.sub}">${title}</div>${inner}</div>`;
  const sdRow = (title, value, dot) => `<div style="display:flex;align-items:center;gap:7px;height:18px">${dot ? `<i style="width:10px;height:10px;border-radius:2.5px;background:${dot};flex:none"></i>` : ''}<span style="font-size:11px;color:rgba(255,255,255,.8)">${title}</span><b style="margin-left:auto;font-size:11px;font-weight:600;color:${SD.ink};font-variant-numeric:tabular-nums">${value}</b></div>`;
  const sdRows = rows => sdCard(`<div style="display:flex;flex-direction:column;gap:4.5px">${rows.join('')}</div>`);
  const sdHeader = (title, icon) => `<div style="display:flex;align-items:center;gap:8px;padding:1px 2px"><span style="display:grid;place-items:center;min-width:20px;height:20px;padding:0 4.5px;box-sizing:border-box;border-radius:5px;background:rgba(254,188,51,.14);color:${SD.gold}">${icon}</span><span style="font-size:12.5px;font-weight:600;color:${SD.ink}">${title}</span></div>`;
  const sdFooter = (title, icon) => `<div style="display:flex;align-items:center;gap:6px;height:26px;padding:0 9px;border-radius:6px;background:rgba(255,255,255,.035);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.08)"><span style="color:${SD.gold};display:grid">${icon}</span><span style="font-size:11px;font-weight:500;color:${SD.ink}">${title}</span><span style="margin-left:auto;color:${SD.sub};display:grid">${sdIcons.out}</span></div>`;
  const sdChart = (values, color) => {
    const w = 232, h = 56, step = w / (values.length - 1);
    const y = v => h - Math.min(1, Math.max(0, v / 100)) * (h - 2) - 1;
    const line = values.map((v, i) => `${i ? 'L' : 'M'}${(i * step).toFixed(1)} ${y(v).toFixed(1)}`).join('');
    const id = `g${color.replace(/[^0-9a-z]/gi, '')}`;
    return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" style="display:block;width:100%;height:${h}px;border-radius:6px"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".95"/><stop offset="1" stop-color="${color}" stop-opacity=".45"/></linearGradient></defs><path d="${line}L${w} ${h}L0 ${h}Z" fill="url(#${id})"/><path d="${line}" fill="none" stroke="rgba(255,255,255,.35)" stroke-width="1"/></svg>`;
  };
  const sdWave = (n, base, amp, period, jitter = 0) => Array.from({ length: n }, (_, i) => base + amp * Math.sin(i / period) + (jitter ? (i % 7) * jitter : 0));

  function statsDetail(o = {}) {
    const mode = o.mode || 'cpu';
    const d = Object.assign({
      cpu: 23, system: 8, user: 15, idle: 77, load: 2.41, cores: [41, 33, 27, 19, 12, 9, 7, 5],
      levels: [['Performance', 4], ['Efficiency', 4]], uptime: '3 days, 4 hrs',
      memTotal: 16, memApp: 6.1, memWired: 2.1, memComp: 1.2, memCached: 4.0, memFree: 0.9, swap: 0,
      gpu: 18, renderer: 15, tiler: 6, gpuMem: '820 MB', gpuAlloc: '2.0 GB', gpuCores: 10, gpuName: 'Apple M2',
      battery: 82, remaining: '3 hr 57 min', power: '18.6 W', amps: '-1580 mA', volts: '11.79 V', temp: '31.4 °C', charge: '2886 / 4382 mAh', cycles: 223, health: '82%',
    }, o.data || {});
    let body;
    if (mode === 'cleanup') {
      const c = Object.assign({
        groups: [
          { t: 'User Caches', badge: 'safe', detail: 'App and browser caches in ~/Library/Caches. Apps rebuild them as needed.', size: '3.29 GB', on: true },
          { t: 'User Logs', badge: 'safe', detail: 'Old log files in ~/Library/Logs. Apps start fresh logs.', size: '732 KB', on: true },
          { t: 'Developer Caches', badge: 'safe', detail: 'npm, Yarn, pnpm, Homebrew, SwiftPM and Xcode build caches. Rebuilt on the next install or build.', size: '1.78 GB', on: true },
          { t: 'Trash', badge: 'caution', detail: "Files already in your Trash. They can't be recovered afterwards.", size: '412.7 MB', on: false },
        ],
        headline: '5.07 GB', sub: 'of 5.48 GB across 4 categories', button: 'Clean 5.07 GB',
      }, o.clean || {});
      const badge = b => { const col = b === 'safe' ? SD.green : SD.orange; return `<span style="font-size:8px;font-weight:700;letter-spacing:.4px;color:${col};padding:1.5px 4px;border-radius:3px;background:${col}26">${b.toUpperCase()}</span>`; };
      const box = on => `<span style="width:14px;height:14px;border-radius:4px;flex:none;display:grid;place-items:center;margin-top:1px;background:${on ? SD.gold : 'rgba(255,255,255,.1)'}">${on ? '<svg width="9" height="9" viewBox="0 0 10 10"><path d="M2 5.2l2 2L8.2 3" fill="none" stroke="rgba(0,0,0,.88)" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>' : ''}</span>`;
      const rows = c.groups.map((g, i) => `${i ? '<div style="height:1px;background:rgba(255,255,255,.08)"></div>' : ''}<div style="display:flex;align-items:flex-start;gap:8px">${box(g.on)}<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:2px"><div style="display:flex;align-items:center;gap:5px"><b style="font-size:11.5px;font-weight:600;color:${SD.ink}">${g.t}</b>${badge(g.badge)}</div><span style="font-size:10px;line-height:1.35;color:${SD.sub}">${g.detail}</span></div><b style="font-size:11px;font-weight:600;color:${SD.ink};font-variant-numeric:tabular-nums;white-space:nowrap">${g.size}</b></div>`).join('');
      const enabled = c.button.startsWith('Clean');
      body = [
        sdHeader('Quick Clean', sdIcons.sparkles),
        sdCard(`<div style="display:flex;align-items:center;gap:11px;padding:2px 0"><span style="width:44px;height:44px;border-radius:50%;flex:none;display:grid;place-items:center;background:rgba(254,188,51,.14);color:${SD.gold}"><svg width="20" height="20" viewBox="0 0 16 16" fill="currentColor"><path d="M7 1.2l1.4 3.9 3.9 1.4-3.9 1.4L7 11.8 5.6 7.9 1.7 6.5l3.9-1.4z"/><path d="M12.4 9.4l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"/></svg></span><div style="flex:1;display:flex;flex-direction:column;gap:2px"><b style="font-size:20px;font-weight:600;color:${SD.ink};font-variant-numeric:tabular-nums">${c.headline}</b><span style="font-size:10.5px;color:${SD.sub}">${c.sub}</span></div><span style="width:22px;height:22px;border-radius:5px;display:grid;place-items:center;background:rgba(255,255,255,.06);color:${SD.sub}"><svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M13 8a5 5 0 1 1-1.5-3.6M13 2.5v3h-3"/></svg></span></div>`),
        sdSection('Categories', sdCard(`<div style="display:flex;flex-direction:column;gap:7px">${rows}</div>`)),
        `<div data-role="qc-clean" style="height:28px;border-radius:7px;display:flex;align-items:center;justify-content:center;gap:6px;font-size:12px;font-weight:700;${enabled ? 'color:rgba(0,0,0,.88);background:linear-gradient(#FEBC33,#E89B00)' : `color:${SD.sub};background:rgba(255,255,255,.07)`}">${sdIcons.trash}${c.button}</div>`,
        sdFooter('Open Cleanup Settings', sdIcons.sliders),
      ];
      const overlay = c.confirm ? `<div style="position:absolute;inset:0;border-radius:14px;background:rgba(0,0,0,.42);display:grid;place-items:center;z-index:3"><div style="width:296px;box-sizing:border-box;padding:12px 14px;border-radius:12px;background:#262527;box-shadow:inset 0 0 0 .8px rgba(255,255,255,.12),0 3px 8px rgba(0,0,0,.4);display:flex;flex-direction:column;align-items:center;gap:10px;text-align:center"><svg width="22" height="26" viewBox="0 0 16 18" fill="#FF453A"><path d="M5.5 1h5l.6 1.6H15v1.6H1V2.6h3.9z"/><path d="M2.4 5.6h11.2l-.9 11.4H3.3z"/></svg><div style="display:flex;flex-direction:column;gap:3px"><b style="font-size:13px;color:${SD.ink}">${c.confirm.title}</b><span style="font-size:11px;line-height:1.4;color:${SD.sub}">${c.confirm.sub}</span></div><div style="display:flex;gap:8px;width:100%"><span style="flex:1;height:24px;border-radius:6px;display:grid;place-items:center;font-size:11.5px;font-weight:500;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.12)">Cancel</span><span data-role="qc-ok" style="flex:1;height:24px;border-radius:6px;display:grid;place-items:center;font-size:11.5px;font-weight:700;color:#fff;background:linear-gradient(#FF3B30,#D22828)">Clean</span></div></div></div>` : '';
      const toast = c.toast ? `<div style="position:absolute;left:50%;bottom:20px;transform:translateX(-50%);z-index:4;display:flex;align-items:center;gap:6px;padding:7px 14px;border-radius:999px;background:rgba(0,0,0,.78);color:#fff;font-size:12px;font-weight:500;white-space:nowrap">${S.check}${c.toast}</div>` : '';
      return `<div class="qx-stats-panel" style="position:relative;width:330px;font-family:'Inter',-apple-system,system-ui,sans-serif;color:${SD.ink};text-align:left;-webkit-font-smoothing:antialiased">${chrome(o.arrowX || 165, o.glass)}<div style="height:12px"></div><div style="position:relative;z-index:1;padding:12px 10px 10px;border-radius:14px;display:flex;flex-direction:column;gap:10px">${body.join('')}${overlay}${toast}</div></div>`;
    } else if (mode === 'memory') {
      const used = d.memApp + d.memWired + d.memComp, frac = used / d.memTotal;
      const gaugeR = 39, gx = 45, gy = 66, ang = Math.PI * (1 + frac);
      const gauge = `<div style="display:flex;flex-direction:column;align-items:center;gap:3px;width:90px"><svg width="90" height="72" viewBox="0 0 90 72"><path d="M${gx - gaugeR} ${gy}A${gaugeR} ${gaugeR} 0 0 1 ${gx + gaugeR} ${gy}" fill="none" stroke="${SD.gray}" stroke-width="7"/><path d="M${gx - gaugeR} ${gy}A${gaugeR} ${gaugeR} 0 0 1 ${(gx + gaugeR * Math.cos(ang)).toFixed(2)} ${(gy + gaugeR * Math.sin(ang)).toFixed(2)}" fill="none" stroke="${SD.blue}" stroke-width="7"/><path d="M${gx} ${gy}L${(gx + (gaugeR - 8) * Math.cos(ang)).toFixed(2)} ${(gy + (gaugeR - 8) * Math.sin(ang)).toFixed(2)}" stroke="${SD.gold}" stroke-width="2.5" stroke-linecap="round"/><circle cx="${gx}" cy="${gy}" r="3" fill="${SD.gold}"/></svg><span style="font-size:11px;font-weight:600;color:${SD.sub};margin-top:-2px">Memory used</span></div>`;
      const gb = v => `${v.toFixed(2)} GB`;
      const bar = `<div style="display:flex;gap:1.5px;height:7px;margin:2px 0">${[[d.memApp, SD.blue], [d.memWired, SD.orange], [d.memComp, SD.pink]].map(([v, c]) => `<i style="width:${(v / d.memTotal * 100).toFixed(2)}%;border-radius:2px;background:${c}"></i>`).join('')}</div>`;
      body = [
        sdHeader('Memory Usage', sdIcons.memory),
        sdCard(`<div style="display:flex;align-items:center;justify-content:center;gap:16px;padding:2px 0">${gauge}${sdRing([[d.memApp / d.memTotal, SD.blue], [d.memWired / d.memTotal, SD.orange], [d.memComp / d.memTotal, SD.pink]], `${Math.round(frac * 100)}%`, 72, 8)}</div>`),
        sdSection('Usage History', sdCard(sdChart(sdWave(90, frac * 100, 3, 9), SD.chart))),
        sdSection('Details', sdRows([sdRow('Used:', gb(used)), bar, sdRow('App:', gb(d.memApp), SD.blue), sdRow('Wired:', gb(d.memWired), SD.orange), sdRow('Compressed:', gb(d.memComp), SD.pink), sdRow('Cached:', gb(d.memCached)), sdRow('Free:', gb(d.memFree), SD.gray), sdRow('Swap:', d.swap ? gb(d.swap) : 'None', SD.yellow)])),
        sdFooter('Open Activity Monitor', sdIcons.wave),
      ];
    } else if (mode === 'gpu') {
      body = [
        sdHeader('GPU Usage', sdIcons.gpu),
        sdCard(`<div style="display:flex;align-items:center;gap:16px;padding:3px 0">${sdRing([[d.gpu / 100, SD.pink]], `${d.gpu}%`, 78, 8.5)}<div style="display:flex;flex-direction:column;gap:3px"><b style="font-size:11px;font-weight:600;color:${SD.ink}">${d.gpuName}</b><span style="font-size:10px;color:${SD.sub}">${d.gpuCores} cores</span><span style="font-size:10px;color:${SD.sub}">In use: ${d.gpuMem}</span></div></div>`),
        sdSection('Usage History', sdCard(sdChart(sdWave(90, d.gpu, 5, 5), SD.pink))),
        sdSection('Details', sdRows([sdRow('Utilization:', `${d.gpu}%`, SD.pink), sdRow('Renderer:', `${d.renderer}%`, SD.pink), sdRow('Tiler:', `${d.tiler}%`, SD.pink), sdRow('Memory in use:', d.gpuMem, SD.blue), sdRow('Allocated:', d.gpuAlloc, SD.blue), sdRow('Cores:', d.gpuCores), sdRow('Device:', d.gpuName)])),
        sdFooter('Open Activity Monitor', sdIcons.activity),
      ];
    } else if (mode === 'battery') {
      body = [
        sdHeader('Battery Status', sdIcons.battery),
        sdCard(`<div style="display:flex;flex-direction:column;gap:6px;padding:2px 0"><div style="display:flex;align-items:center;gap:10px"><svg width="44" height="22" viewBox="0 0 22 12"><rect x="1" y="1.5" width="17" height="9" rx="2.6" fill="none" stroke="${SD.ink}" stroke-width="1"/><rect x="2.6" y="3.1" width="${(13.8 * d.battery / 100).toFixed(1)}" height="5.8" rx="1.4" fill="${SD.ink}"/><path d="M19.6 4.6v2.8c.7-.2 1.1-.8 1.1-1.4s-.4-1.2-1.1-1.4z" fill="${SD.ink}"/></svg><b style="font-size:22px;font-weight:600;color:${SD.ink}">${d.battery}%</b></div><span style="font-size:11px;color:${SD.sub}">Power Source: Battery</span><span style="font-size:11px;color:${SD.sub}">Remaining: ${d.remaining}</span></div>`),
        sdSection('Details', sdRows([sdRow('Power:', d.power), sdRow('Amperage:', d.amps, SD.orange), sdRow('Voltage:', d.volts), sdRow('Temperature:', d.temp, SD.green), sdRow('Charge:', d.charge, SD.blue), sdRow('Cycle Count:', d.cycles), sdRow('Max Capacity:', d.health)])),
        sdFooter('Open Battery Settings', sdIcons.batteryBlock),
      ];
    } else {
      const logical = d.levels.reduce((a, l) => a + l[1], 0) || 1;
      const bars = `<div style="display:flex;gap:4px;height:34px">${d.cores.map(v => `<div style="flex:1;display:flex;align-items:flex-end;border-radius:3px;background:rgba(255,255,255,.07)"><i style="display:block;width:100%;height:${Math.max(3, 34 * Math.min(100, v) / 100).toFixed(1)}px;border-radius:3px;background:${SD.blue}"></i></div>`).join('')}</div>`;
      body = [
        sdHeader('CPU Usage', sdIcons.cpu),
        sdCard(`<div style="display:flex;align-items:center;justify-content:center;gap:16px;padding:3px 0">${sdRing([[d.system / 100, SD.red], [d.user / 100, SD.blue], [d.idle / 100, SD.gray]], `${d.cpu}%`, 78, 8.5)}<div style="display:flex;flex-direction:column;align-items:center;gap:3px">${sdRing([[d.load / logical, SD.blue]], d.load.toFixed(2), 50, 5.5)}<span style="font-size:9.5px;font-weight:500;color:${SD.sub}">load</span></div></div>`),
        sdSection('Usage History', sdCard(`<div style="display:flex;flex-direction:column;gap:8px">${sdChart(o.history || sdWave(90, Math.max(8, d.cpu - 5), 9, 6, 1), SD.chart)}${bars}</div>`)),
        sdSection('Details', sdRows([sdRow('System:', `${d.system}%`, SD.red), sdRow('User:', `${d.user}%`, SD.blue), sdRow('Idle:', `${d.idle}%`, SD.gray), ...d.levels.map((l, i) => sdRow(`${l[0]} cores:`, l[1], levelColor(i))), sdRow('Uptime:', d.uptime)])),
        sdFooter('Open Activity Monitor', sdIcons.activity),
      ];
    }
    return `<div class="qx-stats-panel" style="position:relative;width:270px;font-family:'Inter',-apple-system,system-ui,sans-serif;color:${SD.ink};text-align:left;-webkit-font-smoothing:antialiased">${chrome(o.arrowX || 135, o.glass)}<div style="height:12px"></div><div style="position:relative;z-index:1;padding:12px 10px 10px;border-radius:14px;display:flex;flex-direction:column;gap:10px">${body.join('')}</div></div>`;
  }

  window.QX = { S, APPS, BACKGROUND, PORTS, icon, popover, ports, confirm, menu, stats, rescue, note, settings, general, automation, portSettings, overview, aboutTab, statsDetail, sideShift, uninstallTab, filesTab, scanHead, LEFTOVERS, CACHES, fitAll };
})();
