// Seed data
const SEED_CUSTOMERS = [
  { id: 'c001', name: 'Manoj Patel',     village: 'Ranasan',    mobile: '98765 43210', type: 'Domestic',   due: 340,   empty: 2, business: 18400, active: true },
  { id: 'c002', name: 'Manoj Patel',     village: 'Gambhoi',    mobile: '94321 87654', type: 'Domestic',   due: 0,     empty: 0, business: 9200,  active: true },
  { id: 'c003', name: 'Ramesh Shah',     village: 'Khedbrahma', mobile: '99887 76655', type: 'Commercial', due: 1200,  empty: 1, business: 52000, active: true },
  { id: 'c004', name: 'Anil Desai',      village: 'Himatnagar', mobile: '98250 12345', type: 'Commercial', due: 4800,  empty: 3, business: 126000,active: true },
  { id: 'c005', name: 'Priya Joshi',     village: 'Idar',       mobile: '97234 56789', type: 'Domestic',   due: 0,     empty: 0, business: 6800,  active: true },
  { id: 'c006', name: 'Kiran Mehta',     village: 'Prantij',    mobile: '98982 33445', type: 'Domestic',   due: 220,   empty: 1, business: 12300, active: true },
  { id: 'c007', name: 'Bhavna Trivedi',  village: 'Talod',      mobile: '95123 77889', type: 'Domestic',   due: 0,     empty: 0, business: 7600,  active: true },
  { id: 'c008', name: 'Vikram Solanki',  village: 'Ranasan',    mobile: '94280 11223', type: 'Commercial', due: 2800,  empty: 2, business: 88000, active: true },
  { id: 'c009', name: 'Sonal Chauhan',   village: 'Himatnagar', mobile: '98245 66778', type: 'Domestic',   due: 0,     empty: 0, business: 4200,  active: true },
  { id: 'c010', name: 'Dinesh Parmar',   village: 'Vadali',     mobile: '97891 00223', type: 'Commercial', due: 6200,  empty: 4, business: 147000,active: true },
  { id: 'c011', name: 'Hiten Rathod',    village: 'Gambhoi',    mobile: '98256 44556', type: 'Domestic',   due: 0,     empty: 0, business: 3400,  active: false },
  { id: 'c012', name: 'Jignesh Pandya',  village: 'Khedbrahma', mobile: '96871 55443', type: 'Commercial', due: 950,   empty: 1, business: 36000, active: true },
  { id: 'c013', name: 'Nita Sharma',     village: 'Idar',       mobile: '95867 99112', type: 'Domestic',   due: 560,   empty: 2, business: 11200, active: true },
  { id: 'c014', name: 'Rohit Makwana',   village: 'Talod',      mobile: '98127 33668', type: 'Domestic',   due: 0,     empty: 1, business: 8700,  active: true },
  { id: 'c015', name: 'Ashok Prajapati', village: 'Himatnagar', mobile: '99099 22447', type: 'Commercial', due: 3150,  empty: 2, business: 72000, active: true },
  { id: 'c016', name: 'Lata Vaghela',    village: 'Prantij',    mobile: '94286 55310', type: 'Domestic',   due: 0,     empty: 0, business: 5100,  active: true },
  { id: 'c017', name: 'Suresh Thakkar',  village: 'Vadali',     mobile: '98790 44221', type: 'Commercial', due: 1800,  empty: 1, business: 41000, active: true },
  { id: 'c018', name: 'Parul Bhatt',     village: 'Ranasan',    mobile: '98246 11778', type: 'Domestic',   due: 0,     empty: 0, business: 3900,  active: true },
  { id: 'c019', name: 'Mahesh Panchal',  village: 'Gambhoi',    mobile: '95588 33210', type: 'Domestic',   due: 120,   empty: 0, business: 8200,  active: true },
  { id: 'c020', name: 'Rekha Dave',      village: 'Idar',       mobile: '97124 88665', type: 'Domestic',   due: 0,     empty: 0, business: 6000,  active: true },
];

const SEED_PRODUCTS = [
  { cat: 'LPG Cylinder', icon: 'cylinder', variants: [
    { id:'p1', name:'Domestic 14.2kg',   size:'14.2 kg', price: 1100, deposit: 2200, returnable: true,  gst: 5, stock: 142 },
    { id:'p2', name:'Commercial 5kg',    size:'5 kg',    price: 650,  deposit: 1600, returnable: true,  gst: 5, stock: 34  },
    { id:'p3', name:'Commercial 15kg',   size:'15 kg',   price: 1800, deposit: 2500, returnable: true,  gst: 5, stock: 88  },
    { id:'p4', name:'Commercial 21kg',   size:'21 kg',   price: 2400, deposit: 3000, returnable: true,  gst: 5, stock: 41  },
    { id:'p5', name:'Commercial 47kg',   size:'47 kg',   price: 4800, deposit: 5500, returnable: true,  gst: 5, stock: 12  },
  ]},
  { cat: 'Regulators & Accessories', icon: 'box', variants: [
    { id:'p6', name:'Standard Regulator', size:'—',        price: 250, deposit: 0, returnable: false, gst: 18, stock: 57 },
    { id:'p7', name:'ISI Rubber Pipe',    size:'1.5 m',    price: 180, deposit: 0, returnable: false, gst: 18, stock: 104 },
    { id:'p8', name:'Gas Lighter',        size:'—',        price: 90,  deposit: 0, returnable: false, gst: 18, stock: 89 },
    { id:'p9', name:'Clamp Set',          size:'Pack of 4',price: 60,  deposit: 0, returnable: false, gst: 18, stock: 210 },
  ]},
  { cat: 'Stoves', icon: 'box', variants: [
    { id:'p10', name:'2-Burner Stainless', size:'Standard', price: 2400, deposit: 0, returnable: false, gst: 18, stock: 6 },
    { id:'p11', name:'3-Burner Glass Top', size:'Large',    price: 4200, deposit: 0, returnable: false, gst: 18, stock: 3 },
  ]},
];

const SEED_BILLS = (() => {
  const out = [];
  const startDate = new Date(2026, 3, 20); // Apr 20, 2026
  const modes = ['Cash','UPI','Cash','Cash','Credit','Cheque','UPI','Cash'];
  for (let i = 0; i < 48; i++) {
    const d = new Date(startDate);
    d.setDate(d.getDate() - Math.floor(i / 6));
    const c = SEED_CUSTOMERS[i % SEED_CUSTOMERS.length];
    const prod = SEED_PRODUCTS[0].variants[i % 5];
    const qty = 1 + (i % 3);
    const total = prod.price * qty + (i % 4 === 0 ? 250 : 0);
    const mode = modes[i % modes.length];
    const paid = mode === 'Credit' ? 0 : mode === 'Cheque' ? Math.round(total * 0.6) : total;
    out.push({
      id: String(2400 + i).padStart(4, '0'),
      date: d,
      cust: c,
      items: [
        { prod: prod, qty, empty: prod.returnable ? qty - (i%2) : 0 },
        ...(i % 4 === 0 ? [{ prod: SEED_PRODUCTS[1].variants[0], qty: 1, empty: 0 }] : []),
      ],
      subtotal: total,
      gst: Math.round(total * 0.05),
      total: total + Math.round(total * 0.05),
      paid,
      mode,
    });
  }
  return out;
})();

const fmtINR = (n) => {
  if (n === null || n === undefined || isNaN(n)) return '₹0';
  const abs = Math.abs(Math.round(n));
  const s = abs.toString();
  let result = '';
  if (s.length <= 3) result = s;
  else {
    const last3 = s.slice(-3);
    const rest = s.slice(0, -3);
    result = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last3;
  }
  return (n < 0 ? '-₹' : '₹') + result;
};

const fmtDate = (d) => {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${String(d.getDate()).padStart(2,'0')}-${months[d.getMonth()]}-${d.getFullYear()}`;
};

const fmtDateShort = (d) => {
  return `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}/${String(d.getFullYear()).slice(2)}`;
};

const initials = (name) => name.split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase();

Object.assign(window, { SEED_CUSTOMERS, SEED_PRODUCTS, SEED_BILLS, fmtINR, fmtDate, fmtDateShort, initials });
