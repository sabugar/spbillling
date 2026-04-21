const CustomersScreen = ({ openCustomer, go }) => {
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState('all');
  const [selected, setSelected] = useState(new Set());
  const [page, setPage] = useState(1);
  const pageSize = 10;

  const filtered = useMemo(() => {
    return SEED_CUSTOMERS.filter(c => {
      if (filter === 'due' && c.due === 0) return false;
      if (filter === 'empty' && c.empty === 0) return false;
      if (filter === 'domestic' && c.type !== 'Domestic') return false;
      if (filter === 'commercial' && c.type !== 'Commercial') return false;
      if (!q) return true;
      const qq = q.toLowerCase();
      return c.name.toLowerCase().includes(qq) ||
             c.village.toLowerCase().includes(qq) ||
             c.mobile.replace(/\s/g,'').includes(qq.replace(/\s/g,''));
    });
  }, [q, filter]);

  const pageRows = filtered.slice((page-1)*pageSize, page*pageSize);
  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));

  const toggleAll = () => {
    if (selected.size === pageRows.length) setSelected(new Set());
    else setSelected(new Set(pageRows.map(r=>r.id)));
  };

  return (
    <div className="page">
      <div className="page-h">
        <div>
          <h1>Customers</h1>
          <div className="sub">{SEED_CUSTOMERS.length} total · {SEED_CUSTOMERS.filter(c=>c.due>0).length} with dues</div>
        </div>
        <div className="right">
          <button className="btn secondary"><Icon name="upload" size={14}/> Import</button>
          <button className="btn secondary"><Icon name="download" size={14}/> Export</button>
          <button className="btn primary"><Icon name="plus" size={14}/> Add Customer</button>
        </div>
      </div>

      <div className="filters">
        <div className="input-with-icon" style={{flex:1, maxWidth:380}}>
          <span className="ii"><Icon name="search" size={16}/></span>
          <input className="input" placeholder="Search by name, mobile, village…" value={q} onChange={e=>{setQ(e.target.value); setPage(1);}}/>
        </div>
        <div className="filter-chip" onClick={()=>setFilter('all')} data-on={filter==='all'} style={filter==='all'?{background:'var(--brand-50)',borderColor:'var(--brand-500)',color:'var(--brand-700)'}:{}}>All <span className="muted">({SEED_CUSTOMERS.length})</span></div>
        <div className={`filter-chip ${filter==='due'?'on':''}`} onClick={()=>setFilter('due')}>With dues</div>
        <div className={`filter-chip ${filter==='empty'?'on':''}`} onClick={()=>setFilter('empty')}>Empty pending</div>
        <div className={`filter-chip ${filter==='domestic'?'on':''}`} onClick={()=>setFilter('domestic')}>Domestic</div>
        <div className={`filter-chip ${filter==='commercial'?'on':''}`} onClick={()=>setFilter('commercial')}>Commercial</div>
        <div style={{flex:1}}/>
        <button className="btn ghost sm"><Icon name="filter" size={14}/> More filters</button>
      </div>

      {selected.size > 0 && (
        <div className="filters" style={{background:'var(--brand-50)', borderColor:'var(--brand-500)'}}>
          <span style={{fontWeight:600, color:'var(--brand-700)'}}>{selected.size} selected</span>
          <button className="btn secondary sm">Send SMS</button>
          <button className="btn secondary sm">Export</button>
          <button className="btn secondary sm">Mark inactive</button>
          <div style={{flex:1}}/>
          <button className="btn ghost sm" onClick={()=>setSelected(new Set())}>Clear</button>
        </div>
      )}

      <div className="tbl-wrap">
        <table className="tbl">
          <thead>
            <tr>
              <th className="chk">
                <label className="checkbox">
                  <input type="checkbox" checked={selected.size===pageRows.length && pageRows.length>0} onChange={toggleAll}/>
                  <span className="box"/>
                </label>
              </th>
              <th>Name</th>
              <th>Village</th>
              <th>Mobile</th>
              <th>Type</th>
              <th className="num">Due</th>
              <th className="num">Empty</th>
              <th className="num">Business</th>
              <th style={{width:40}}></th>
            </tr>
          </thead>
          <tbody>
            {pageRows.map(c => (
              <tr key={c.id} className={`clickable ${!c.active?'inactive':''}`} onClick={()=>openCustomer(c)}>
                <td className="chk" onClick={e=>e.stopPropagation()}>
                  <label className="checkbox">
                    <input type="checkbox" checked={selected.has(c.id)} onChange={(e)=>{
                      const ns = new Set(selected);
                      e.target.checked ? ns.add(c.id) : ns.delete(c.id);
                      setSelected(ns);
                    }}/>
                    <span className="box"/>
                  </label>
                </td>
                <td>
                  <div className="flex center gap-8">
                    <div style={{width:28, height:28, borderRadius:'50%', background:'var(--brand-100)', color:'var(--brand-700)', display:'grid', placeItems:'center', fontWeight:700, fontSize:11}}>{initials(c.name)}</div>
                    <div style={{fontWeight:600}}>{highlight(c.name, q)}</div>
                    {!c.active && <span className="badge muted">Inactive</span>}
                  </div>
                </td>
                <td>{highlight(c.village, q)}</td>
                <td className="mono">{c.mobile}</td>
                <td><span className={`badge ${c.type==='Commercial'?'brand':'muted'}`}>{c.type}</span></td>
                <td className="num" style={{fontWeight: c.due>0?700:400, color: c.due>0?'var(--err-600)':'var(--text-3)'}}>{c.due>0?fmtINR(c.due):'—'}</td>
                <td className="num">
                  {c.empty>0 ? <span className="badge warn">{c.empty}</span> : <span className="muted">—</span>}
                </td>
                <td className="num muted">{fmtINR(c.business)}</td>
                <td onClick={e=>e.stopPropagation()}>
                  <button className="icon-btn-s"><Icon name="more" size={14}/></button>
                </td>
              </tr>
            ))}
            {pageRows.length === 0 && (
              <tr><td colSpan={9}>
                <div className="empty">
                  <div className="glyph"><Icon name="search" size={24}/></div>
                  <div style={{fontWeight:600}}>No customers match</div>
                  <div className="small muted">Try a different search or filter.</div>
                </div>
              </td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="flex" style={{justifyContent:'space-between', alignItems:'center', marginTop:12, fontSize:13, color:'var(--text-2)'}}>
        <div>Showing {(page-1)*pageSize+1}–{Math.min(page*pageSize, filtered.length)} of {filtered.length}</div>
        <div className="flex gap-4">
          <button className="btn secondary sm" disabled={page===1} onClick={()=>setPage(p=>p-1)}><Icon name="chevleft" size={14}/></button>
          <div className="flex center" style={{padding:'0 10px'}}>Page {page} of {totalPages}</div>
          <button className="btn secondary sm" disabled={page===totalPages} onClick={()=>setPage(p=>p+1)}><Icon name="chevright" size={14}/></button>
        </div>
      </div>
    </div>
  );
};

const CustomerDetail = ({ customer, onClose, go }) => {
  const [tab, setTab] = useState('tx');
  const txs = SEED_BILLS.filter(b => b.cust.id === customer.id).slice(0, 20);
  return (
    <Drawer onClose={onClose} width={640}>
      <div className="cd-hero">
        <div className="avatar">{initials(customer.name)}</div>
        <div style={{flex:1}}>
          <div className="n">{customer.name}</div>
          <div className="m">{customer.village} · {customer.mobile} · {customer.type}</div>
        </div>
        <div className="right">
          <button className="btn secondary sm"><Icon name="phone" size={14}/></button>
          <button className="btn secondary sm"><Icon name="message" size={14}/></button>
          <button className="btn secondary sm"><Icon name="edit" size={14}/></button>
          <button className="btn secondary sm" onClick={onClose}><Icon name="x" size={14}/></button>
        </div>
      </div>
      <div className="cd-cards">
        <div className={`cd-card ${customer.due>0?'warn':''}`}>
          <div className="k">Total Due</div>
          <div className="v">{fmtINR(customer.due)}</div>
        </div>
        <div className="cd-card">
          <div className="k">Empty Bottles</div>
          <div className="v">{customer.empty}</div>
        </div>
        <div className="cd-card ok">
          <div className="k">Lifetime Business</div>
          <div className="v">{fmtINR(customer.business)}</div>
        </div>
      </div>
      <div className="tabs">
        {[['tx','Transactions'],['pay','Payments'],['emp','Empty History'],['notes','Notes']].map(([k,l])=>(
          <div key={k} className={`tab ${tab===k?'on':''}`} onClick={()=>setTab(k)}>{l}</div>
        ))}
      </div>
      <div style={{flex:1, overflow:'auto', padding:16}}>
        {tab === 'tx' && (
          <div className="tbl-wrap">
            <table className="tbl">
              <thead><tr><th>Date</th><th>Bill</th><th>Items</th><th className="num">Total</th><th>Status</th></tr></thead>
              <tbody>
                {txs.length === 0 && <tr><td colSpan={5}><div className="empty"><div className="glyph"><Icon name="doc" size={24}/></div><div>No transactions yet</div></div></td></tr>}
                {txs.map(b=>(
                  <tr key={b.id} className="clickable">
                    <td className="mono small">{fmtDateShort(b.date)}</td>
                    <td className="mono">#{b.id}</td>
                    <td>{b.items.map(i=>`${i.prod.name} ×${i.qty}`).join(', ')}</td>
                    <td className="num" style={{fontWeight:600}}>{fmtINR(b.total)}</td>
                    <td>
                      <span className={`badge ${b.paid>=b.total?'ok':b.paid===0?'err':'warn'}`}>
                        {b.paid>=b.total?'Paid':b.paid===0?'Unpaid':'Partial'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {tab === 'pay' && (
          <div className="empty"><div className="glyph"><Icon name="cash" size={24}/></div><div>Payment history</div><div className="small muted">Receipts and collections for {customer.name}</div></div>
        )}
        {tab === 'emp' && (
          <div className="empty"><div className="glyph"><Icon name="cylinder" size={24}/></div><div>Empty bottle ledger</div><div className="small muted">{customer.empty} bottles pending return</div></div>
        )}
        {tab === 'notes' && (
          <div className="empty"><div className="glyph"><Icon name="doc" size={24}/></div><div>No notes yet</div><button className="btn secondary sm mt-12"><Icon name="plus" size={12}/> Add note</button></div>
        )}
      </div>
      <div style={{padding:16, borderTop:'1px solid var(--divider)', display:'flex', gap:8, justifyContent:'flex-end'}}>
        <button className="btn secondary" onClick={onClose}>Close</button>
        <button className="btn primary" onClick={()=>{ onClose(); go('newbill', customer); }}><Icon name="plus" size={14}/> New Bill</button>
      </div>
    </Drawer>
  );
};

window.CustomersScreen = CustomersScreen;
window.CustomerDetail = CustomerDetail;
