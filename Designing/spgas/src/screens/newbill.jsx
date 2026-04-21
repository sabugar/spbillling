const NewBillScreen = ({ preselected, toast, onSaved }) => {
  const [customer, setCustomer] = useState(preselected || null);
  const [custSearch, setCustSearch] = useState('');
  const [custFocus, setCustFocus] = useState(false);
  const [custIdx, setCustIdx] = useState(0);
  const [items, setItems] = useState([]);
  const [mode, setMode] = useState('Cash');
  const [paid, setPaid] = useState(0);
  const [returned, setReturned] = useState(0);
  const [date, setDate] = useState('20-Apr-2026');
  const custInput = useRef(null);

  const custMatches = useMemo(() => {
    if (!custSearch) return [];
    const q = custSearch.toLowerCase();
    return SEED_CUSTOMERS.filter(c =>
      c.name.toLowerCase().includes(q) ||
      c.village.toLowerCase().includes(q) ||
      c.mobile.replace(/\s/g,'').includes(q.replace(/\s/g,''))
    ).slice(0, 6);
  }, [custSearch]);

  useEffect(() => {
    const handler = (e) => {
      if (e.key === 'F4') { e.preventDefault(); custInput.current?.focus(); }
      if (e.key === 'Escape') { setCustFocus(false); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, []);

  const selectCustomer = (c) => {
    setCustomer(c);
    setCustSearch('');
    setCustFocus(false);
  };

  const subtotal = items.reduce((s,i) => s + (i.qty * i.rate), 0);
  const gst = Math.round(subtotal * 0.05);
  const prevDue = customer?.due || 0;
  const grand = subtotal + gst + prevDue;
  const balance = grand - (parseFloat(paid) || 0);

  const newCyls = items.filter(i=>i.prod?.returnable).reduce((s,i)=>s+i.qty, 0);
  const prevEmpty = customer?.empty || 0;
  const totalOwing = prevEmpty + newCyls - (parseInt(returned)||0);

  useEffect(() => { setPaid(mode === 'Credit' ? 0 : grand); }, [grand, mode]);

  const addItem = () => {
    setItems([...items, { id: Math.random(), prod: null, qty: 1, rate: 0, empty: 0 }]);
  };
  const updateItem = (id, patch) => {
    setItems(items.map(i => i.id === id ? { ...i, ...patch } : i));
  };
  const removeItem = (id) => setItems(items.filter(i => i.id !== id));

  const save = (andPrint) => {
    if (!customer) { toast.push({kind:'err', title:'Customer required', msg:'Please select a customer first'}); return; }
    if (items.length === 0) { toast.push({kind:'err', title:'Add items', msg:'Bill must have at least one item'}); return; }
    toast.push({kind:'ok', title: andPrint?'Bill saved & printed':'Bill saved', msg:`#2448 · ${fmtINR(grand)} · ${customer.name}`});
    onSaved?.();
  };

  return (
    <div className="page">
      <div className="page-h">
        <div>
          <h1>New Bill</h1>
          <div className="sub">Press <Kbd k="F4"/> to search customer · <Kbd k="Tab"/> between fields · <Kbd k="Ctrl+↵"/> save & print</div>
        </div>
        <div className="right">
          <div className="field" style={{flexDirection:'row', alignItems:'center', gap:8}}>
            <label style={{margin:0, whiteSpace:'nowrap'}}>Bill Date</label>
            <div className="input-with-icon" style={{width:160}}>
              <span className="ii"><Icon name="calendar" size={14}/></span>
              <input className="input" value={date} onChange={e=>setDate(e.target.value)}/>
            </div>
          </div>
          <div className="mono small muted" style={{marginLeft:8}}>Bill #2448</div>
        </div>
      </div>

      <div className="bill-layout">
        <div>
          {/* Customer section */}
          <div className="bill-section">
            <div className="bill-section-h">
              <Icon name="user" size={12}/> Customer
              {customer && <span className="badge ok" style={{marginLeft:'auto'}}>Selected</span>}
            </div>
            <div className="bill-section-b">
              {!customer ? (
                <div className="cust-search-wrap">
                  <div className="input-with-icon">
                    <span className="ii"><Icon name="search" size={16}/></span>
                    <input
                      ref={custInput}
                      className="input"
                      placeholder="Search by mobile or name…"
                      value={custSearch}
                      onFocus={()=>setCustFocus(true)}
                      onBlur={()=>setTimeout(()=>setCustFocus(false), 150)}
                      onChange={e=>{setCustSearch(e.target.value); setCustIdx(0);}}
                      onKeyDown={e=>{
                        if (e.key === 'ArrowDown') { e.preventDefault(); setCustIdx(i=>Math.min(i+1, custMatches.length-1)); }
                        else if (e.key === 'ArrowUp') { e.preventDefault(); setCustIdx(i=>Math.max(i-1, 0)); }
                        else if (e.key === 'Enter' && custMatches[custIdx]) { selectCustomer(custMatches[custIdx]); }
                      }}
                      autoFocus
                    />
                  </div>
                  {custFocus && custSearch && custMatches.length > 0 && (
                    <div className="cust-dropdown">
                      {custMatches.map((c, i) => (
                        <div key={c.id} className={`cust-opt ${i===custIdx?'focused':''}`} onMouseDown={()=>selectCustomer(c)} onMouseEnter={()=>setCustIdx(i)}>
                          <div className="avatar">{initials(c.name)}</div>
                          <div>
                            <div className="n">{highlight(c.name, custSearch)} — {highlight(c.village, custSearch)}</div>
                            <div className="s">{highlight(c.mobile, custSearch)} · {c.type}</div>
                          </div>
                          <div className="meta">
                            {c.due > 0 ? <div style={{color:'var(--err-600)', fontWeight:600}}>{fmtINR(c.due)} due</div> : <div className="muted">No dues</div>}
                            {c.empty > 0 && <div style={{color:'var(--warn-700)'}}>{c.empty} empty</div>}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                  {custFocus && custSearch && custMatches.length === 0 && (
                    <div className="cust-dropdown">
                      <div style={{padding:14, textAlign:'center'}} className="muted small">
                        No match. <a href="#" style={{color:'var(--brand-600)', fontWeight:600}}>+ Create new customer</a>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="cust-selected">
                  <div className="avatar">{initials(customer.name)}</div>
                  <div>
                    <div className="n">{customer.name} — {customer.village}</div>
                    <div className="m"><Icon name="phone" size={11} style={{display:'inline',verticalAlign:'middle'}}/> {customer.mobile} · <span className="badge muted">{customer.type}</span></div>
                  </div>
                  <div className="stats">
                    <div>
                      <div className="k">Prev Due</div>
                      <div className="v" style={{color: customer.due>0?'var(--err-600)':'inherit'}}>{fmtINR(customer.due)}</div>
                    </div>
                    <div>
                      <div className="k">Empty Pending</div>
                      <div className="v" style={{color: customer.empty>0?'var(--warn-700)':'inherit'}}>{customer.empty}</div>
                    </div>
                    <button className="btn ghost sm" onClick={()=>{setCustomer(null); setTimeout(()=>custInput.current?.focus(),50);}}><Icon name="x" size={12}/> Change</button>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Products */}
          <div className="bill-section">
            <div className="bill-section-h">
              <Icon name="cylinder" size={12}/> Products
              <span style={{marginLeft:'auto'}} className="muted small">{items.length} {items.length===1?'item':'items'}</span>
            </div>
            <div className="bill-section-b" style={{padding:0}}>
              <table className="items-tbl">
                <thead>
                  <tr>
                    <th style={{width:36, paddingLeft:14}}>#</th>
                    <th>Product</th>
                    <th className="num" style={{width:80}}>Qty</th>
                    <th className="num" style={{width:100}}>Rate</th>
                    <th className="num" style={{width:80}}>Empty</th>
                    <th className="num" style={{width:110}}>Amount</th>
                    <th style={{width:36}}></th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((it, idx) => (
                    <ItemRow key={it.id} idx={idx+1} item={it} onChange={(p)=>updateItem(it.id, p)} onRemove={()=>removeItem(it.id)} />
                  ))}
                  <tr className="add-row">
                    <td colSpan={7}>
                      <button onClick={addItem}><Icon name="plus" size={14}/> Click to add item · <span className="mono muted small" style={{marginLeft:4}}>or press Enter</span></button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* Empty bottles calculation */}
          {customer && (newCyls > 0 || prevEmpty > 0) && (
            <div className="bill-section">
              <div className="bill-section-h"><Icon name="cylinder" size={12}/> Empty Bottles After This Bill</div>
              <div className="bill-section-b">
                <div className="bottles-calc">
                  <div><span className="lbl">Previous</span><div className="v">{prevEmpty}</div></div>
                  <span className="op">+</span>
                  <div><span className="lbl">New</span><div className="v">{newCyls}</div></div>
                  <span className="op">−</span>
                  <div>
                    <span className="lbl">Returned</span>
                    <input className="input" style={{width:70, height:30, padding:'0 8px', marginTop:4, textAlign:'right'}} value={returned} onChange={e=>setReturned(e.target.value)}/>
                  </div>
                  <span className="eq">=</span>
                  <div><span className="lbl">Total Owing</span><div className="v total">{totalOwing}</div></div>
                  {(parseInt(returned)||0) > prevEmpty + newCyls && (
                    <div style={{marginLeft:'auto', color:'var(--err-600)', fontSize:12, fontWeight:600}}>
                      <Icon name="alert" size={12} style={{display:'inline',verticalAlign:'middle'}}/> Returned exceeds outstanding
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Payment */}
          <div className="bill-section">
            <div className="bill-section-h"><Icon name="cash" size={12}/> Payment</div>
            <div className="bill-section-b">
              <div className="pay-modes">
                {[['Cash','cash'],['UPI','upi'],['Card','card'],['Cheque','cheque'],['Credit','credit']].map(([m, ic])=>(
                  <div key={m} className={`pay-mode ${mode===m?'on':''}`} onClick={()=>setMode(m)}>
                    <Icon name={ic} size={16}/> {m}
                  </div>
                ))}
              </div>
              <div className="flex gap-16 mt-16" style={{alignItems:'flex-end'}}>
                <Field label="Amount Paid">
                  <div className="input-with-icon" style={{width:200}}>
                    <span className="ii" style={{fontWeight:700}}>₹</span>
                    <input className="input num" value={paid} onChange={e=>setPaid(e.target.value)}/>
                  </div>
                </Field>
                <div style={{padding:'6px 14px', background: balance>0?'var(--warn-50)':'var(--ok-50)', border:'1px solid', borderColor: balance>0?'var(--warn-100)':'var(--ok-100)', borderRadius:'var(--r-sm)', height:36, display:'flex', alignItems:'center', gap:8}}>
                  <span className="small" style={{color:'var(--text-2)'}}>Balance</span>
                  <span style={{fontWeight:700, color: balance>0?'var(--warn-700)':'var(--ok-700)', fontVariantNumeric:'tabular-nums'}}>{fmtINR(balance)}</span>
                </div>
                {mode === 'Credit' && <div className="badge warn" style={{height:'fit-content'}}>Added to customer dues</div>}
              </div>
            </div>
          </div>

          <div className="action-bar">
            <div className="draft-indicator"><span className="dot"/>Auto-saved as draft</div>
            <div className="spacer"/>
            <button className="btn ghost">Cancel <Kbd k="Esc"/></button>
            <button className="btn secondary">Save Draft</button>
            <button className="btn secondary" onClick={()=>save(true)}><Icon name="printer" size={14}/> Save & Print <Kbd k="Ctrl+↵"/></button>
            <button className="btn primary" onClick={()=>save(false)}><Icon name="check" size={14}/> Save</button>
          </div>
        </div>

        {/* Right summary sidebar */}
        <div>
          <div className="totals" style={{position:'sticky', top:0}}>
            <div style={{fontSize:11, textTransform:'uppercase', letterSpacing:'.06em', fontWeight:700, color:'var(--text-2)', padding:'6px 0 10px', borderBottom:'1px solid var(--divider)'}}>Bill Summary</div>
            <div className="row sub"><span>Subtotal ({items.length} items)</span><span className="v">{fmtINR(subtotal)}</span></div>
            <div className="row sub"><span>GST (5%)</span><span className="v">{fmtINR(gst)}</span></div>
            {prevDue > 0 && <div className="row sub" style={{color:'var(--err-600)'}}><span>Previous Due</span><span className="v">{fmtINR(prevDue)}</span></div>}
            <div className="row grand"><span>Grand Total</span><span className="v">{fmtINR(grand)}</span></div>
            <div className="hline"/>
            <div className="row sub"><span>Payment Mode</span><span style={{fontWeight:600, color:'var(--text)'}}>{mode}</span></div>
            <div className="row sub"><span>Amount Paid</span><span className="v">{fmtINR(parseFloat(paid)||0)}</span></div>
            <div className="row" style={{fontWeight:700, color: balance>0?'var(--warn-700)':'var(--ok-700)'}}><span>Balance</span><span className="v">{fmtINR(balance)}</span></div>
          </div>

          <div className="card mt-12 pad" style={{fontSize:12, color:'var(--text-2)'}}>
            <div style={{fontWeight:700, color:'var(--text)', marginBottom:6, fontSize:13}}><Icon name="clock" size={12} style={{display:'inline',verticalAlign:'middle'}}/> Keyboard shortcuts</div>
            <div className="flex" style={{justifyContent:'space-between', padding:'3px 0'}}><span>New bill</span><Kbd k="F2"/></div>
            <div className="flex" style={{justifyContent:'space-between', padding:'3px 0'}}><span>Focus search</span><Kbd k="F4"/></div>
            <div className="flex" style={{justifyContent:'space-between', padding:'3px 0'}}><span>Next field</span><Kbd k="Tab"/></div>
            <div className="flex" style={{justifyContent:'space-between', padding:'3px 0'}}><span>Save & print</span><Kbd k="Ctrl+↵"/></div>
            <div className="flex" style={{justifyContent:'space-between', padding:'3px 0'}}><span>Cancel</span><Kbd k="Esc"/></div>
          </div>
        </div>
      </div>
    </div>
  );
};

const ItemRow = ({ idx, item, onChange, onRemove }) => {
  const [search, setSearch] = useState(item.prod?.name || '');
  const [focused, setFocused] = useState(!item.prod);
  const [pIdx, setPIdx] = useState(0);
  const allProds = SEED_PRODUCTS.flatMap(g => g.variants.map(v => ({...v, cat: g.cat})));
  const matches = useMemo(()=>{
    if (!search) return allProds.slice(0, 8);
    const q = search.toLowerCase();
    return allProds.filter(p => p.name.toLowerCase().includes(q) || p.cat.toLowerCase().includes(q)).slice(0, 8);
  },[search]);

  const pick = (p) => {
    setSearch(p.name);
    setFocused(false);
    onChange({ prod: p, rate: p.price, empty: p.returnable ? item.qty : 0 });
  };

  return (
    <tr>
      <td style={{paddingLeft:14, color:'var(--text-3)'}}>{idx}</td>
      <td style={{position:'relative'}}>
        <input
          className="cell-input text"
          value={search}
          placeholder="Type to search product…"
          onFocus={()=>setFocused(true)}
          onBlur={()=>setTimeout(()=>setFocused(false), 150)}
          onChange={e=>{setSearch(e.target.value); setPIdx(0);}}
          onKeyDown={e=>{
            if (e.key === 'ArrowDown') { e.preventDefault(); setPIdx(i=>Math.min(i+1, matches.length-1)); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); setPIdx(i=>Math.max(i-1, 0)); }
            else if (e.key === 'Enter' && matches[pIdx]) { pick(matches[pIdx]); }
          }}
        />
        {focused && matches.length > 0 && (
          <div className="prod-pop">
            {matches.map((p, i) => (
              <div key={p.id} className={`prod-opt ${i===pIdx?'focused':''}`} onMouseDown={()=>pick(p)} onMouseEnter={()=>setPIdx(i)}>
                <div>
                  <div className="pn">{p.name}</div>
                  <div className="pv">{p.cat} · {p.size} {p.returnable?'· Returnable':''}</div>
                </div>
                <div className="pr">{fmtINR(p.price)}</div>
              </div>
            ))}
          </div>
        )}
        {item.prod && <div style={{fontSize:10, color:'var(--text-3)', marginTop:2, paddingLeft:8}}>{item.prod.cat} · GST {item.prod.gst}%</div>}
      </td>
      <td className="num">
        <input className="cell-input" type="number" value={item.qty} onChange={e=>onChange({qty: parseInt(e.target.value)||0})}/>
      </td>
      <td className="num">
        <input className="cell-input" type="number" value={item.rate} onChange={e=>onChange({rate: parseFloat(e.target.value)||0})}/>
      </td>
      <td className="num">
        {item.prod?.returnable
          ? <input className="cell-input" type="number" value={item.empty} onChange={e=>onChange({empty: parseInt(e.target.value)||0})}/>
          : <span className="muted">—</span>}
      </td>
      <td className="num" style={{fontWeight:700, paddingRight:14}}>{fmtINR(item.qty * item.rate)}</td>
      <td>
        <button className="rowbtn" onClick={onRemove}><Icon name="trash" size={14}/></button>
      </td>
    </tr>
  );
};

window.NewBillScreen = NewBillScreen;
