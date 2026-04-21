const BillsScreen = ({ go }) => {
  const [range, setRange] = useState('today');
  const [q, setQ] = useState('');
  const [modeFilter, setModeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selected, setSelected] = useState(new Set());

  const filtered = useMemo(() => {
    return SEED_BILLS.filter(b => {
      if (modeFilter !== 'all' && b.mode !== modeFilter) return false;
      if (statusFilter === 'paid' && b.paid < b.total) return false;
      if (statusFilter === 'unpaid' && b.paid >= b.total) return false;
      if (!q) return true;
      const qq = q.toLowerCase();
      return b.id.includes(qq) ||
             b.cust.name.toLowerCase().includes(qq) ||
             b.cust.mobile.includes(qq);
    });
  }, [q, modeFilter, statusFilter]);

  const toggleAll = () => {
    if (selected.size === filtered.length) setSelected(new Set());
    else setSelected(new Set(filtered.map(r=>r.id)));
  };

  const totals = filtered.reduce((s,b)=>({ amt: s.amt+b.total, paid: s.paid+b.paid }),{amt:0,paid:0});

  return (
    <div className="page">
      <div className="page-h">
        <div><h1>Bills</h1><div className="sub">{filtered.length} bills · {fmtINR(totals.amt)} total · {fmtINR(totals.amt - totals.paid)} outstanding</div></div>
        <div className="right">
          <button className="btn secondary"><Icon name="download" size={14}/> Excel</button>
          <button className="btn secondary" onClick={()=>go('print', [...selected])}><Icon name="printer" size={14}/> Print {selected.size>0?`(${selected.size})`:'Multi'}</button>
          <button className="btn primary" onClick={()=>go('newbill')}><Icon name="plus" size={14}/> New Bill</button>
        </div>
      </div>

      <div className="filters">
        <Segmented options={[
          {value:'today', label:'Today'},
          {value:'week', label:'This Week'},
          {value:'month', label:'This Month'},
          {value:'custom', label:'Custom'},
        ]} value={range} onChange={setRange}/>
        <div className="input-with-icon" style={{flex:1, maxWidth:320}}>
          <span className="ii"><Icon name="search" size={16}/></span>
          <input className="input" placeholder="Bill #, customer, mobile…" value={q} onChange={e=>setQ(e.target.value)}/>
        </div>
        <select className="select" style={{width:140}} value={modeFilter} onChange={e=>setModeFilter(e.target.value)}>
          <option value="all">All modes</option>
          <option>Cash</option><option>UPI</option><option>Card</option><option>Cheque</option><option>Credit</option>
        </select>
        <select className="select" style={{width:140}} value={statusFilter} onChange={e=>setStatusFilter(e.target.value)}>
          <option value="all">All status</option>
          <option value="paid">Paid</option>
          <option value="unpaid">Unpaid/Partial</option>
        </select>
      </div>

      {selected.size > 0 && (
        <div className="filters" style={{background:'var(--brand-50)', borderColor:'var(--brand-500)'}}>
          <span style={{fontWeight:600, color:'var(--brand-700)'}}>{selected.size} bills selected</span>
          <button className="btn primary sm" onClick={()=>go('print', [...selected])}><Icon name="printer" size={14}/> Print 9-per-page</button>
          <button className="btn secondary sm">Export PDF</button>
          <div style={{flex:1}}/>
          <button className="btn ghost sm" onClick={()=>setSelected(new Set())}>Clear</button>
        </div>
      )}

      <div className="tbl-wrap">
        <table className="tbl">
          <thead><tr>
            <th className="chk"><label className="checkbox"><input type="checkbox" checked={selected.size===filtered.length && filtered.length>0} onChange={toggleAll}/><span className="box"/></label></th>
            <th>Bill #</th><th>Date</th><th>Customer</th><th>Items</th><th>Mode</th>
            <th className="num">Total</th><th className="num">Paid</th><th className="num">Balance</th>
            <th style={{width:80}}>Status</th><th style={{width:40}}></th>
          </tr></thead>
          <tbody>
            {filtered.slice(0, 30).map(b=>{
              const bal = b.total - b.paid;
              return (
                <tr key={b.id} className="clickable">
                  <td className="chk" onClick={e=>e.stopPropagation()}>
                    <label className="checkbox"><input type="checkbox" checked={selected.has(b.id)} onChange={(e)=>{const ns=new Set(selected); e.target.checked?ns.add(b.id):ns.delete(b.id); setSelected(ns);}}/><span className="box"/></label>
                  </td>
                  <td className="mono" style={{fontWeight:600}}>#{b.id}</td>
                  <td className="mono small">{fmtDateShort(b.date)}</td>
                  <td>
                    <div style={{fontWeight:600}}>{b.cust.name}</div>
                    <div className="sub">{b.cust.village} · {b.cust.mobile}</div>
                  </td>
                  <td className="small muted">{b.items.map(i=>`${i.prod.name.split(' ').slice(-1)[0]}×${i.qty}`).join(', ')}</td>
                  <td><span className={`badge ${b.mode==='Credit'?'warn':'muted'}`}>{b.mode}</span></td>
                  <td className="num" style={{fontWeight:600}}>{fmtINR(b.total)}</td>
                  <td className="num">{fmtINR(b.paid)}</td>
                  <td className="num" style={{color:bal>0?'var(--err-600)':'inherit', fontWeight:bal>0?600:400}}>{bal>0?fmtINR(bal):'—'}</td>
                  <td>
                    <span className={`badge ${bal===0?'ok':b.paid===0?'err':'warn'}`}>
                      {bal===0?'Paid':b.paid===0?'Unpaid':'Partial'}
                    </span>
                  </td>
                  <td onClick={e=>e.stopPropagation()}><button className="icon-btn-s"><Icon name="more" size={14}/></button></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

window.BillsScreen = BillsScreen;
