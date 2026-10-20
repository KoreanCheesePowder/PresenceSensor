/* TYPE6 SmartThings Status API adapter for CheesePowder System Monitor.
 * Works as a script include (window.Type6StatusAdapter) or CommonJS import.
 * Read-only, no credentials or network calls.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.Type6StatusAdapter = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';
  const SUFFIX = '.type6communication';
  const LABEL = { checking: '통신 확인 중', normal: '통신 정상', suspect: '통신 끊김 의심' };

  function extractType6Status(deviceStatus, platformHealth) {
    const main = deviceStatus?.components?.main || {};
    const capId = Object.keys(main).find(k => k.toLowerCase().endsWith(SUFFIX));
    if (!capId || !main[capId] || typeof main[capId] !== 'object') return null;
    const cap = main[capId];
    const val = (key, fallback) => cap[key]?.value ?? fallback;
    const rawLink = val('linkState', 'checking');
    const link = Object.hasOwn(LABEL, rawLink) ? rawLink : 'checking';
    const cloud = String(typeof platformHealth === 'string'
      ? platformHealth : platformHealth?.state || 'UNKNOWN').toUpperCase();
    const monitorStatus = cloud === 'OFFLINE' ? 'offline'
      : link === 'suspect' || cloud === 'UNHEALTHY' ? 'caution'
      : link === 'normal' || cloud === 'ONLINE' ? 'online' : 'unknown';
    return {
      capability_id: capId,
      link_state: link,
      platform_health: cloud,
      monitor_status: monitorStatus,
      communication_label: LABEL[link],
      silence_minutes: val('minutesWithoutRx', 0),
      last_received: val('lastReceived', '없음'),
      timeout_minutes: val('timeoutMinutes', 60),
    };
  }

  function type6AlarmTransition(previous, current) {
    if (!previous || !current || previous.link_state === current.link_state ||
        current.platform_health === 'OFFLINE') return null;
    if (current.link_state === 'suspect')
      return {event: 'type6_link_suspect', severity: 'warning', title: 'TYPE6 통신 끊김 의심'};
    if (previous.link_state === 'suspect' && current.link_state === 'normal')
      return {event: 'type6_link_recovered', severity: 'recovery', title: 'TYPE6 통신 정상 복구'};
    return null;
  }
  return {extractType6Status, type6AlarmTransition};
});
