// DOM overlay: inventory slots (grow as you find new things), health + stamina, clock, target hint,
// loot toasts and a soft red-paper flash when hurt.
const $ = (id) => document.getElementById(id);

// small printed-paper icons for every item
const ICONS = {
  gold: '<path d="M6 22 C8 15 12 12 16 12 C20 12 24 15 26 22 Z" fill="#d8a830" stroke="#7a5a14" stroke-width="1.5"/><circle cx="12" cy="18" r="1.6" fill="#ffe08a"/><circle cx="18" cy="16" r="1.4" fill="#ffe08a"/><circle cx="21" cy="19" r="1.2" fill="#ffe08a"/>',
  dollars: '<rect x="5" y="9" width="22" height="14" rx="2" fill="#8aa870" stroke="#3e5a2a" stroke-width="1.5"/><circle cx="16" cy="16" r="4" fill="none" stroke="#3e5a2a" stroke-width="1.4"/><path d="M16 13 L16 19" stroke="#3e5a2a" stroke-width="1.2"/>',
  sang: '<path d="M16 28 L16 12" stroke="#4a6a34" stroke-width="2"/><ellipse cx="10" cy="15" rx="6" ry="3" fill="#6a8c46" transform="rotate(-25 10 15)"/><ellipse cx="22" cy="15" rx="6" ry="3" fill="#6a8c46" transform="rotate(25 22 15)"/><circle cx="14" cy="8" r="2.6" fill="#d43a2c"/><circle cx="18" cy="8" r="2.6" fill="#d43a2c"/><circle cx="16" cy="5" r="2.6" fill="#c4362f"/>',
  silver: '<path d="M5 22 L9 11 L18 7 L27 13 L26 23 L14 26 Z" fill="#a85a3a" stroke="#50241a" stroke-width="1.5"/><path d="M9 20 L15 15 L19 17 L24 11" stroke="#eef2f6" stroke-width="3" fill="none" stroke-linejoin="round"/>',
  pearl: '<ellipse cx="16" cy="19" rx="11" ry="7" fill="#3a4a5c" stroke="#1e2a36" stroke-width="1.5"/><ellipse cx="16" cy="18" rx="7" ry="4" fill="#d8e2ea"/><circle cx="16" cy="17" r="3.4" fill="#fbf8f2" stroke="#b8c4cc" stroke-width="0.8"/>',
  geode: '<path d="M4 22 A12 12 0 0 1 28 22 Z" fill="#a89880" stroke="#50422f" stroke-width="1.5"/><path d="M8 22 A8 8 0 0 1 24 22 Z" fill="#8a6ab8"/><path d="M12 22 A4 4 0 0 1 20 22 Z" fill="#5e3e8e"/>',
  amber: '<path d="M16 5 C21 12 24 16 24 20 A8 8 0 0 1 8 20 C8 16 11 12 16 5 Z" fill="#e0a030" stroke="#8a5a14" stroke-width="1.5"/><path d="M12 18 Q13 13 16 10" stroke="#fff0c0" stroke-width="1.6" fill="none"/>',
  wood: '<rect x="4" y="11" width="24" height="10" rx="5" fill="#a0703f" stroke="#5b3d22" stroke-width="1.5"/><circle cx="24" cy="16" r="4.2" fill="#e2c28e" stroke="#5b3d22" stroke-width="1.2"/>',
  stone: '<path d="M5 22 L9 11 L18 7 L27 13 L26 23 L14 26 Z" fill="#9b978c" stroke="#4f4c45" stroke-width="1.5"/>',
  berries: '<circle cx="11" cy="18" r="5" fill="#c8323c" stroke="#6e1a20" stroke-width="1.3"/><circle cx="21" cy="17" r="5" fill="#d8434c" stroke="#6e1a20" stroke-width="1.3"/><circle cx="16" cy="24" r="4.5" fill="#b92a34" stroke="#6e1a20" stroke-width="1.3"/>',
  fiber: '<path d="M10 27 C10 18 8 12 6 6 M16 27 C16 17 16 11 17 4 M22 27 C22 18 24 12 27 7" fill="none" stroke="#7d9150" stroke-width="2.4" stroke-linecap="round"/>',
  clay: '<path d="M5 23 C6 15 12 11 17 11 C23 11 27 16 27 23 Z" fill="#b8693f" stroke="#6e3a20" stroke-width="1.5"/>',
  mushrooms: '<rect x="13" y="16" width="5" height="10" fill="#efe3cc" stroke="#6e5a40" stroke-width="1.2"/><path d="M5 17 C5 9 27 9 27 17 Z" fill="#c4362f" stroke="#6e1a14" stroke-width="1.4"/><circle cx="12" cy="13" r="1.6" fill="#f6efe0"/><circle cx="19" cy="12" r="1.6" fill="#f6efe0"/>',
  honey: '<path d="M9 9 H23 L25 26 H7 Z" fill="#e0a83a" stroke="#7a5418" stroke-width="1.5"/><rect x="8" y="6" width="16" height="4" fill="#efe3cc" stroke="#7a5418" stroke-width="1.2"/>',
  ore: '<path d="M5 22 L9 11 L18 7 L27 13 L26 23 L14 26 Z" fill="#8f8a86" stroke="#4f4c45" stroke-width="1.5"/><circle cx="13" cy="16" r="2.2" fill="#c46a32"/><circle cx="20" cy="19" r="2" fill="#e0a050"/>',
  iron: '<path d="M6 21 L10 12 H24 L27 21 Z" fill="#9aa0a6" stroke="#4a4e54" stroke-width="1.5"/>',
  rope: '<circle cx="16" cy="16" r="9" fill="none" stroke="#b89a5a" stroke-width="3"/><circle cx="16" cy="16" r="4.5" fill="none" stroke="#b89a5a" stroke-width="2.4"/>',
  oats: '<path d="M9 10 Q16 6 23 10 L25 27 H7 Z" fill="#e8d8a8" stroke="#6a5030" stroke-width="1.5"/><path d="M12 16 l2 3 M17 15 l1 4 M20 18 l-2 3 M13 22 l3 1 M19 23 l2 -2" stroke="#a88848" stroke-width="1.6" stroke-linecap="round"/>',
  mash: '<path d="M8 9 Q16 5 24 9 L26 27 H6 Z" fill="#d8c8a0" stroke="#6a5030" stroke-width="1.5"/><path d="M10 9 Q16 13 22 9" fill="none" stroke="#6a5030" stroke-width="1.2"/><circle cx="13" cy="20" r="1.4" fill="#c8a040"/><circle cx="18" cy="18" r="1.4" fill="#c8a040"/><circle cx="17" cy="23" r="1.4" fill="#c8a040"/>',
  savings: '<path d="M5 12 H27 V27 H5 Z" fill="#5a5e62" stroke="#2a2c30" stroke-width="1.5"/><path d="M5 12 L8 7 H24 L27 12" fill="#6e7276" stroke="#2a2c30" stroke-width="1.5"/><circle cx="16" cy="19" r="3.4" fill="#d9a441" stroke="#6a4a20" stroke-width="1.2"/><path d="M16 17 V21 M14 19 H18" stroke="#6a4a20" stroke-width="1"/>',
  cartridges: '<path d="M8 12 H20 L26 16 L20 20 H8 Z" fill="#d9a441" stroke="#6a4a20" stroke-width="1.4" stroke-linejoin="round"/><path d="M8 12 V20" stroke="#8a6a30" stroke-width="3"/><path d="M20 12 L26 16 L20 20 Z" fill="#8a8a8e" stroke="#4a4a4e" stroke-width="1"/>',
  venison: '<path d="M6 18 C6 10 14 7 21 9 C27 11 28 18 24 23 C19 27 9 26 6 18 Z" fill="#a8483a" stroke="#5a2a20" stroke-width="1.5"/><path d="M11 15 C14 13 19 13 22 16" fill="none" stroke="#efd8c0" stroke-width="1.6"/><path d="M24 20 L29 26" stroke="#efe2c4" stroke-width="3" stroke-linecap="round"/>',
  roast: '<ellipse cx="16" cy="22" rx="13" ry="5" fill="#d8cdb4" stroke="#7a6a50" stroke-width="1.3"/><path d="M7 20 C7 13 14 10 20 11 C26 12 27 18 24 21 Z" fill="#8a4a26" stroke="#4a2410" stroke-width="1.4"/><path d="M11 16 L13 18 M16 14 L18 17 M21 15 L22 18" stroke="#c88a4a" stroke-width="1.2"/>',
  pelt: '<path d="M8 8 C12 10 20 10 24 8 L26 24 C20 27 12 27 6 24 Z" fill="#a8865c" stroke="#5a4428" stroke-width="1.5"/>',
  stew: '<path d="M5 15 H27 C27 23 22 26 16 26 C10 26 5 23 5 15 Z" fill="#8a5a3a" stroke="#4a2e1c" stroke-width="1.5"/><ellipse cx="16" cy="15" rx="11" ry="3" fill="#c4362f"/>',
  corn: '<path d="M16 4 C22 8 22 22 16 28 C10 22 10 8 16 4 Z" fill="#e8c04a" stroke="#8a6a1c" stroke-width="1.4"/><path d="M9 27 C9 18 11 12 15 8 M23 27 C23 18 21 12 17 8" fill="none" stroke="#7d9150" stroke-width="2.6"/>',
  wheat: '<path d="M16 28 V8" stroke="#9a7436" stroke-width="1.6"/><path d="M11 27 L15 10 M21 27 L17 10" stroke="#9a7436" stroke-width="1.4"/>' + [6, 10, 14, 18].map((y) => `<ellipse cx="13.5" cy="${y}" rx="2.2" ry="3.2" fill="#e2bf6a" stroke="#8a6a1c" stroke-width="0.9" transform="rotate(-25 13.5 ${y})"/><ellipse cx="18.5" cy="${y}" rx="2.2" ry="3.2" fill="#e2bf6a" stroke="#8a6a1c" stroke-width="0.9" transform="rotate(25 18.5 ${y})"/>`).join('') + '<path d="M12 21 H20" stroke="#b5473a" stroke-width="2"/>',
  ribbon: '<path d="M13 18 L10 29 L14 26 L16 29 L17 18 Z M19 18 L22 29 L18 26 L16 29 L15 18 Z" fill="#3f5f8a" stroke="#22324a" stroke-width="1"/><circle cx="16" cy="12" r="8" fill="#4f6f96" stroke="#22324a" stroke-width="1.3"/><circle cx="16" cy="12" r="4" fill="#d9a441"/>',
  giantpumpkin: '<path d="M16 7 C27 7 31 13 31 20 C31 27 25 29 16 29 C7 29 1 27 1 20 C1 13 5 7 16 7 Z" fill="#de7a32" stroke="#8c3c14" stroke-width="1.5"/><path d="M10 8 C7 15 7 23 10 29 M22 8 C25 15 25 23 22 29 M16 7 V29" fill="none" stroke="#b0501e" stroke-width="1.2"/><rect x="14.5" y="2" width="3" height="6" fill="#5b6a3a"/><circle cx="25" cy="6" r="3" fill="#4f6f96"/>',
  bread: '<path d="M5 22 C5 12 27 12 27 22 L26 25 H6 Z" fill="#c98a48" stroke="#6e4422" stroke-width="1.5"/><path d="M10 16 L13 19 M15 14 L18 17 M20 15 L23 18" stroke="#f0d49a" stroke-width="1.6"/>',
  pumpkin: '<path d="M16 9 C24 9 28 13 28 19 C28 25 23 27 16 27 C9 27 4 25 4 19 C4 13 8 9 16 9 Z" fill="#de7a32" stroke="#8c3c14" stroke-width="1.5"/><path d="M12 10 C10 16 10 22 12 27 M20 10 C22 16 22 22 20 27" fill="none" stroke="#b0501e" stroke-width="1.3"/><rect x="14.5" y="4" width="3" height="6" fill="#5b6a3a"/>',
  cornbread: '<rect x="5" y="12" width="22" height="12" rx="2" fill="#e8b84a" stroke="#8a5a1c" stroke-width="1.5"/><path d="M12 12 V24 M20 12 V24" stroke="#c49030" stroke-width="1.3"/>',
  bricks: '<path d="M4 20 H17 V27 H4 Z M15 13 H28 V20 H15 Z M17 20 H28 V27 H17 Z M4 13 H15 V20 H4 Z" fill="#b5543a" stroke="#5a2a1a" stroke-width="1.5"/>',
  charcoal: '<path d="M5 22 L9 13 L16 11 L22 14 L27 21 L20 26 L10 26 Z" fill="#2e2a28" stroke="#111" stroke-width="1.5"/><path d="M10 18 L15 15 M17 20 L22 17" stroke="#6a625c" stroke-width="1.5"/>',
  steel: '<path d="M4 14 L10 9 H28 L22 14 Z" fill="#c8ccd0" stroke="#4a4e52" stroke-width="1.5"/><path d="M4 14 H22 V23 H4 Z" fill="#a4aab0" stroke="#4a4e52" stroke-width="1.5"/><path d="M22 14 L28 9 V18 L22 23 Z" fill="#7e848a" stroke="#4a4e52" stroke-width="1.5"/>',
  leather: '<path d="M6 8 Q10 5 16 7 Q22 5 26 8 L25 24 Q20 27 16 25 Q12 27 7 24 Z" fill="#a86a3a" stroke="#5a3418" stroke-width="1.5"/><path d="M9 11 Q16 9 23 11 M9 20 Q16 22 23 20" stroke="#d8a874" stroke-width="1.2" fill="none" stroke-dasharray="2 2"/>',
  sap: '<path d="M9 9 H23 L21 27 H11 Z" fill="#a9adae" stroke="#4f5254" stroke-width="1.5"/><path d="M10 14 H22" stroke="#4f5254" stroke-width="1.2"/><path d="M11 12 H21 L20.5 15 H11.5 Z" fill="#d8e4e8"/>',
  syrup: '<path d="M12 4 H20 V9 Q26 12 26 18 V27 H6 V18 Q6 12 12 9 Z" fill="#c8823a" stroke="#6a3a18" stroke-width="1.5"/><path d="M9 18 H23" stroke="#f3e2c0" stroke-width="2"/><rect x="13" y="3" width="6" height="3" fill="#6a3a18"/>',
  johnnycake: '<ellipse cx="16" cy="20" rx="12" ry="5" fill="#d9a441" stroke="#7a5418" stroke-width="1.5"/><ellipse cx="16" cy="16" rx="11" ry="4.5" fill="#e8b85a" stroke="#7a5418" stroke-width="1.5"/><path d="M10 15 Q16 19 22 15" stroke="#a85a1a" stroke-width="2.5" fill="none"/>',
  flour: '<path d="M8 10 Q16 4 24 10 L26 27 H6 Z" fill="#efe6d2" stroke="#7a6a50" stroke-width="1.5"/><path d="M11 9 Q16 12 21 9" stroke="#7a6a50" stroke-width="1.5" fill="none"/><path d="M11 18 H21 M12 22 H20" stroke="#b5473a" stroke-width="1.5"/>',
  applepie: '<path d="M4 18 H28 L25 25 H7 Z" fill="#c9915a" stroke="#6e4422" stroke-width="1.5"/><path d="M5 18 C8 10 24 10 27 18 Z" fill="#e2b46a" stroke="#8a5a2a" stroke-width="1.5"/><path d="M10 15 L22 15 M12 12 L20 12" stroke="#8a5a2a" stroke-width="1.5"/>',
  pie: '<path d="M4 18 H28 L25 25 H7 Z" fill="#c9915a" stroke="#6e4422" stroke-width="1.5"/><path d="M5 18 C8 11 24 11 27 18 Z" fill="#de7a32" stroke="#8c3c14" stroke-width="1.3"/>',
  fish: '<path d="M4 16 C9 9 19 9 24 16 C19 23 9 23 4 16 Z" fill="#8fa3a0" stroke="#3e5250" stroke-width="1.5"/><path d="M24 16 L29 11 V21 Z" fill="#8fa3a0" stroke="#3e5250" stroke-width="1.5"/><circle cx="9" cy="15" r="1.4" fill="#2b2018"/>',
  fishfry: '<ellipse cx="16" cy="19" rx="12" ry="6" fill="#3a3a3a" stroke="#1e1e1e" stroke-width="1.4"/><path d="M8 18 C11 14 19 14 22 18 C19 22 11 22 8 18 Z" fill="#c9893e" stroke="#7a4a1c" stroke-width="1.2"/>',
  egg: '<ellipse cx="16" cy="17" rx="8" ry="10" fill="#f3ead6" stroke="#8a7a5c" stroke-width="1.5"/><ellipse cx="13" cy="13" rx="2.5" ry="3.5" fill="#fffaf0"/>',
  flapjacks: '<ellipse cx="16" cy="22" rx="12" ry="4" fill="#d9a050" stroke="#7a4a1c" stroke-width="1.3"/><ellipse cx="16" cy="18" rx="12" ry="4" fill="#e2b062" stroke="#7a4a1c" stroke-width="1.3"/><ellipse cx="16" cy="14" rx="12" ry="4" fill="#e8bc70" stroke="#7a4a1c" stroke-width="1.3"/><rect x="13" y="10" width="6" height="3" fill="#f6e4a0"/>',
  milk: '<path d="M9 9 H23 L25 27 H7 Z" fill="#b9bec4" stroke="#4a4e54" stroke-width="1.5"/><path d="M9 12 H23" stroke="#f6f2e8" stroke-width="3"/><path d="M8 9 C8 3 24 3 24 9" fill="none" stroke="#4a4e54" stroke-width="1.5"/>',
  wool: '<circle cx="11" cy="17" r="6" fill="#f3ecdc" stroke="#9a8e78" stroke-width="1.3"/><circle cx="20" cy="15" r="6.5" fill="#f6efe0" stroke="#9a8e78" stroke-width="1.3"/><circle cx="16" cy="22" r="6" fill="#efe6d2" stroke="#9a8e78" stroke-width="1.3"/>',
  biscuits: '<ellipse cx="11" cy="19" rx="7" ry="5" fill="#e6c07a" stroke="#8a5a1c" stroke-width="1.3"/><ellipse cx="21" cy="17" rx="7" ry="5" fill="#ecc884" stroke="#8a5a1c" stroke-width="1.3"/>',
  apples: '<circle cx="12" cy="19" r="7" fill="#c4362f" stroke="#6e1a20" stroke-width="1.3"/><circle cx="21" cy="17" r="7" fill="#d8443a" stroke="#6e1a20" stroke-width="1.3"/><path d="M21 10 L22 6" stroke="#4a3020" stroke-width="1.6"/><ellipse cx="25" cy="7" rx="3" ry="1.6" fill="#7d9150"/>',
  applecrisp: '<path d="M4 17 H28 L25 26 H7 Z" fill="#c9915a" stroke="#6e4422" stroke-width="1.5"/><path d="M5 17 C9 12 23 12 27 17 Z" fill="#e8c27a" stroke="#8a5a1c" stroke-width="1.2"/><circle cx="12" cy="15" r="1.6" fill="#c4362f"/><circle cx="19" cy="14" r="1.6" fill="#c4362f"/>',
  whiskers: '<path d="M3 16 C8 8 20 8 26 16 C20 24 8 24 3 16 Z" fill="#6f7f62" stroke="#2b3324" stroke-width="1.5"/><path d="M26 16 L30 11 V21 Z" fill="#6f7f62" stroke="#2b3324" stroke-width="1.3"/><path d="M5 15 C1 12 0 10 1 8 M5 17 C1 20 0 22 1 24" stroke="#2b2a24" stroke-width="1.3" fill="none"/><circle cx="9" cy="14" r="1.5" fill="#f3ead6"/>',
  honeycake: '<rect x="5" y="13" width="22" height="11" rx="2" fill="#d9a948" stroke="#7a5418" stroke-width="1.5"/><path d="M5 16 H27" stroke="#f6efe0" stroke-width="2"/>',
};
const ORDER = ['ribbon', 'wood', 'stone', 'berries', 'apples', 'fiber', 'rope', 'clay', 'mushrooms', 'honey', 'ore', 'iron', 'pelt', 'venison', 'whiskers', 'milk', 'wool', 'egg', 'fish', 'corn', 'wheat', 'flour', 'bricks', 'sap', 'syrup', 'leather', 'charcoal', 'steel', 'pumpkin', 'giantpumpkin', 'stew', 'fishfry', 'cornbread', 'bread', 'biscuits', 'flapjacks', 'applecrisp', 'pie', 'honeycake'];
const ALWAYS = new Set(['wood', 'stone', 'berries']);
// the always-on ledger (top right): the major building and money stuff
const LEDGER = ['gold', 'wood', 'stone', 'fiber', 'rope', 'clay', 'bricks', 'ore', 'iron', 'charcoal', 'steel', 'silver', 'cartridges', 'savings', 'mash', 'oats'];
const LEDGER_ALWAYS = new Set(['gold', 'wood', 'stone']);
// cooked dishes share one pantry basket slot (best first, as F eats them), so the bar stays one tidy row
const DISHES = ['johnnycake', 'applepie', 'honeycake', 'roast', 'pie', 'applecrisp', 'flapjacks', 'stew', 'fishfry', 'biscuits', 'bread', 'cornbread'];
const BASKET = '<path d="M3 15 H29 L26 28 H6 Z" fill="#b8874f" stroke="#5a3a20" stroke-width="1.5"/><path d="M5 19 H27 M6 23 H26" stroke="#8a5a30" stroke-width="1.2"/><path d="M8 15 C8 5 24 5 24 15" fill="none" stroke="#5a3a20" stroke-width="2"/>';

// the tool bar along the bottom: what's in the farmer's hand (1–5), drawn as little cut-paper tools
const H = 'stroke="#5a3a20" stroke-width="1.5" stroke-linejoin="round"';
export const TOOLBAR = [
  { id: 'hands', name: () => 'Hands', svg: `<path d="M9 28 L8 15 C8 12 11 12 11 15 L11 9 C11 6 14 6 14 9 L14 7 C14 4 17 4 17 7 L17 9 C17 6 20 6 20 9 L20 16 L22 13 C24 11 26 13 25 15 L21 24 L20 28 Z" fill="#e8c49a" ${H}/>` },
  { id: 'axe', name: (t) => (t.has('steelaxe') ? 'Steel axe' : t.has('ironaxe') ? 'Iron axe' : t.has('stoneaxe') ? 'Stone axe' : 'Old hatchet'), svg: `<path d="M9 29 L21 6" stroke="#5a3a20" stroke-width="4.5" stroke-linecap="round"/><path d="M9 29 L21 6" stroke="#a0703f" stroke-width="2.5" stroke-linecap="round"/><path d="M17 8 C22 2 30 6 29 13 L19 12 Z" fill="#b9bec4" ${H}/>` },
  { id: 'pick', name: (t) => (t.has('steelpick') ? 'Steel pickaxe' : t.has('ironpick') ? 'Iron pickaxe' : 'Pickaxe'), svg: `<path d="M10 29 L20 8" stroke="#5a3a20" stroke-width="4.5" stroke-linecap="round"/><path d="M10 29 L20 8" stroke="#a0703f" stroke-width="2.5" stroke-linecap="round"/><path d="M5 9 C12 3 24 3 30 11 C24 8 13 8 5 9 Z" fill="#9a9da2" ${H}/>` },
  { id: 'spear', name: () => 'Ash spear', svg: `<path d="M5 29 L23 9" stroke="#5a3a20" stroke-width="4" stroke-linecap="round"/><path d="M5 29 L23 9" stroke="#c09a68" stroke-width="2" stroke-linecap="round"/><path d="M21 7 L29 3 L26 12 Z" fill="#8e8a80" ${H}/><path d="M19 12 L23 15" stroke="#5a3a20" stroke-width="2.5"/>` },
  { id: 'rod', name: () => 'Fishing pole', svg: `<path d="M5 29 C12 20 20 10 28 4" fill="none" stroke="#5a3a20" stroke-width="3.5" stroke-linecap="round"/><path d="M5 29 C12 20 20 10 28 4" fill="none" stroke="#c8a860" stroke-width="1.8" stroke-linecap="round"/><path d="M28 4 L28 20" stroke="#5a3a20" stroke-width="0.8"/><circle cx="28" cy="22" r="2.6" fill="#c4362f" ${H}/><circle cx="9" cy="24" r="2.6" fill="#b5473a" ${H}/>` },
  { id: 'bow', name: () => 'Hunting bow', svg: `<path d="M9 4 C22 9 22 23 9 28" fill="none" stroke="#5a3a20" stroke-width="3.6" stroke-linecap="round"/><path d="M9 4 C22 9 22 23 9 28" fill="none" stroke="#c09a68" stroke-width="1.8" stroke-linecap="round"/><path d="M9 4 L9 28" stroke="#efe2c4" stroke-width="1"/><path d="M6 16 L28 16" stroke="#8a6038" stroke-width="1.6"/><path d="M28 16 L24 13 L24 19 Z" fill="#8e8a80" ${H}/><path d="M6 16 L3 13 M6 16 L3 19" stroke="#a8352a" stroke-width="2"/>` },
  { id: 'revolver', name: () => 'Six-shooter', svg: `<path d="M6 13 H27 V17 H14 L12 27 H6 L9 17 Z" fill="#6a6a70" ${H}/><path d="M6 18 L9 17 L8 27 H5 Z" fill="#8a5a30" ${H}/><circle cx="15" cy="15" r="3.4" fill="#8e8a90" ${H}/>` },
  { id: 'rifle', name: () => 'Buffalo rifle', svg: `<path d="M2 22 L12 17 L30 10 L31 12 L13 20 L6 27 Z" fill="#8a5a30" ${H}/><path d="M13 17 L31 10" stroke="#4a4a4e" stroke-width="2.4"/>` },
];

export class Hud {
  constructor() {
    this.slots = $('slots');
    this.ledger = $('ledger'); this.ledgerSig = ''; this.ledgerLast = {};
    this.stamina = $('stamina-fill');
    this.staminaBar = $('stamina');
    this.healthFill = $('health-fill');
    this.healthBar = $('health');
    this.hurtEl = $('hurt');
    this.clock = $('clock');
    this.hint = $('hint');
    this.toasts = $('toasts');
    this.backend = $('backend');
    this.last = {};
    this.sig = '';
  }

  setInventory(inv) {
    this.setLedger(inv);
    const shown = ORDER.filter((k) => !DISHES.includes(k) && (ALWAYS.has(k) || (inv[k] || 0) > 0));
    const pantry = DISHES.reduce((n, k) => n + (inv[k] || 0), 0);
    const best = DISHES.find((k) => (inv[k] || 0) > 0);
    if (pantry > 0) shown.push('pantry');
    const sig = shown.join(',') + '|' + best;
    if (sig !== this.sig) {
      this.sig = sig;
      const icon = (k) => (k === 'pantry' ? `${BASKET}<g transform="translate(8 1) scale(.5)">${ICONS[best] || ''}</g>` : ICONS[k] || '');
      this.slots.innerHTML = shown.map((k) => `<div class="slot card${k === 'pantry' ? ' pantry' : ''}" data-k="${k}"><span class="k">${k}</span><svg viewBox="0 0 32 32">${icon(k)}</svg><span class="n">0</span></div>`).join('');
      this.slots.classList.toggle('many', shown.length > 9);
      this.last = {};
    }
    for (const k of shown) {
      const v = k === 'pantry' ? pantry : inv[k] || 0;
      if (this.last[k] === v) continue;
      const slot = this.slots.querySelector(`[data-k="${k}"]`);
      if (!slot) continue;
      slot.querySelector('.n').textContent = v;
      if (this.last[k] !== undefined) { slot.classList.remove('bump'); void slot.offsetWidth; slot.classList.add('bump'); }
      this.last[k] = v;
    }
  }

  /** The ledger, top right: wood, stone and gold always; the other major stuff once you've some of it. */
  setLedger(inv) {
    if (!this.ledger) return;
    const shown = LEDGER.filter((k) => LEDGER_ALWAYS.has(k) || (inv[k] || 0) > 0);
    const sig = shown.join(',');
    if (sig !== this.ledgerSig) {
      this.ledgerSig = sig; this.ledgerLast = {};
      this.ledger.innerHTML = shown.map((k) => `<div class="row" data-k="${k}" title="${k}"><svg viewBox="0 0 32 32">${ICONS[k] || ''}</svg><span class="n">0</span></div>`).join('');
    }
    for (const k of shown) {
      const v = inv[k] || 0; if (this.ledgerLast[k] === v) continue;
      const row = this.ledger.querySelector(`[data-k="${k}"]`); if (!row) continue;
      row.querySelector('.n').textContent = v; row.classList.toggle('zero', v === 0);
      if (this.ledgerLast[k] !== undefined) { row.classList.remove('bump'); void row.offsetWidth; row.classList.add('bump'); }
      this.ledgerLast[k] = v;
    }
  }

  /** The tool bar: rebuilt only when what you own or what's in hand changes. */
  setTools(tools, held, owns, wear = {}) {
    let sig = held;
    for (const k in wear) sig += `|${k}${Math.ceil(wear[k] / 5)}`;
    for (const t of TOOLBAR) sig += owns(t.id) ? t.name(tools) : '-';
    if (sig === this.toolSig) return;
    this.toolSig = sig;
    this.toolbar ??= $('toolbar');
    this.toolbar.innerHTML = TOOLBAR.map((t, i) => {
      const have = owns(t.id);
      const w = wear[t.id], strip = have && w !== undefined ? `<span class="wear${w <= 0 ? ' dull' : ''}"><i style="width:${Math.max(3, w)}%"></i></span>` : '';
      return `<div class="tslot card${t.id === held ? ' on' : ''}${have ? '' : ' locked'}" data-t="${t.id}" title="${have ? t.name(tools) + (w !== undefined ? ` (${w <= 0 ? 'dull' : Math.round(w) + '% sharp'})` : '') : 'not made yet'}"><span class="k">${i + 1}</span><svg viewBox="0 0 32 32">${t.svg}</svg><span class="nm">${have ? t.name(tools) + (w !== undefined && w <= 0 ? ' · dull' : '') : '?'}</span>${strip}</div>`;
    }).join('');
  }

  setStamina(v, max, boosted) {
    this.stamina.style.width = `${(v / max) * 100}%`;
    this.staminaBar.style.width = `${Math.min(360, max * 1.2)}px`;
    this.staminaBar.classList.toggle('boosted', boosted);
    this.staminaBar.classList.toggle('low', v < 15);
  }

  /** The belly: a mustard bar that goes orange and blinks when you're hungry. */
  setFullness(v) {
    this.fullFill ??= $('fullness-fill'); this.fullBar ??= $('fullness');
    this.fullFill.style.width = `${v}%`;
    this.fullBar.classList.toggle('hungry', v < 30);
    this.fullBar.classList.toggle('starving', v < 10);
  }

  setHealth(v, max) {
    this.healthFill.style.width = `${(v / max) * 100}%`;
    this.healthBar.classList.toggle('low', v < max * 0.3);
  }

  hurt() {
    this.hurtEl.classList.remove('show'); void this.hurtEl.offsetWidth; this.hurtEl.classList.add('show');
  }

  setClock(text) { if (this.clock.textContent !== text) this.clock.textContent = text; }

  setHint(text) {
    if (this.hint.textContent !== text) this.hint.textContent = text;
    this.hint.classList.toggle('show', !!text);
  }

  /**
   * A paper note in the corner. Long notes stay up long enough to read (about 2 s plus a beat per word),
   * the same note twice just stays up longer instead of stacking, and at most three are pinned at once:
   * a fourth nudges the oldest away early.
   */
  toast(text) {
    // notes queue: two pinned up at a time, each staying long enough to read; the rest wait their turn (a short
    // "+2 wood" never waits behind a story, it just replaces the last short one)
    const live = [...this.toasts.children].filter((e) => !e.classList.contains('out'));
    const same = live.find((e) => e.textContent === text);
    if (same) { clearTimeout(same._t); same._t = setTimeout(() => this.dismiss(same), this.noteMs(text)); return; }
    this.queue ||= [];
    if (this.queue.includes(text)) return;
    const short = text.length < 40;
    if (short) { const s = live.find((e) => e.textContent.length < 40); if (s) { s.textContent = text; clearTimeout(s._t); s._t = setTimeout(() => this.dismiss(s), this.noteMs(text)); return; } }
    if (live.length >= 2) { if (short) this.queue.unshift(text); else this.queue.push(text); if (this.queue.length > 8) this.queue.splice(1, 1); return; }
    this.pin(text);
  }
  noteMs(text) { return Math.min(10000, 2400 + text.length * 50); }
  pin(text) {
    const el = document.createElement('div');
    el.className = 'toast';
    el.textContent = text;
    el.style.setProperty('--tilt', `${(Math.random() - 0.5) * 1.6}deg`); // pinned up by hand, never quite straight
    this.toasts.appendChild(el);
    el._t = setTimeout(() => this.dismiss(el), this.noteMs(text));
  }

  dismiss(el) {
    if (!el || el.classList.contains('out')) return;
    clearTimeout(el._t);
    el.classList.add('out');
    setTimeout(() => { el.remove(); if (this.queue?.length) this.pin(this.queue.shift()); }, 600);
  }
}
