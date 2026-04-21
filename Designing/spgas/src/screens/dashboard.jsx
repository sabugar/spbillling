const Dashboard = ({ go }) => {
  const topOutstanding = [...SEED_CUSTOMERS].filter(c=>c.due>0).sort((a,b)=>b.due-a.due).slice(0,5);
  const topEmpty = [...SEED_CUSTOMERS].filter(c=>c.empty>0).sort((a,b)=>b.empty-a.empty).slice(0,5);
  const recent = SEED_BILLS.slice(0, 8);
  const totalDue = SEED_CUSTOMERS.reduce((s,c)=>s+c.due, 0);
  const todayBills = SEED_BILLS.filter(b => {
    const d = b.date; const t = new Date(2026,3,20);
    return d.getDate()===t.getDate() && d.getMonth()===t.getMonth();
  });
  const todaySales = todayBills.reduce((s,b)=>s+b.total, 0);
  const todayCash = todayBills.filter(b=>b.mode==='Cash').reduce((s,b)=>s+b.paid,0);
  const todayCyl = todayBills.reduce((s,b)=>s+b.items.filter(i=>i.prod.returnable).reduce((x,i)=>x+i.qty,0),0);

  const bars = [28, 34, 22, 31, 42, 38, 40, 29, 45, 33, 48, 34];

  return (
    <div className="page">
      <div className="page-h">
        <div>
          <h1>Dashboard</h1>
          <div className="sub">Monday · 20 Apr 2026 · Counter open</div>
        </div>
        <div className="right">
          <button className="btn secondary sm"><Icon name="calendar" size={14}/> Today</button>
          <button className="btn primary" onClick={()=>go('newbill')}><Icon name="plus" size={14}/> New Bill</button>
        </div>
      </div>

      <div className="stat-grid">
        <div className="stat accent" onClick={()=>go('bills')}>
          <div className="lbl"><span className="ic"><Icon name="rupee" size={14}/></span>Today's Sales</div>
          <div className="val">{fmtINR(todaySales)}</div>
          <div className="sub">{todayBills.length} bills <span className="delta up"><Icon name="arrowup" size={10}/>12%</span></div>
        </div>
        <div className="stat" onClick={()=>go('bills')}>
          <div className="lbl"><span className="ic" style={{background:'var(--ok-50)',color:'var(--ok-600)'}}><Icon name="cash" size={14}/></span>Cash Collected</div>
          <div className="val">{fmtINR(todayCash)}</div>
          <div className="sub">Across {todayBills.filter(b=>b.mode==='Cash').length} cash bills</div>
        </div>
        <div className="stat" onClick={()=>go('products')}>
          <div className="lbl"><span className="ic" style={{background:'var(--warn-50)',color:'var(--warn-600)'}}><Icon name="cylinder" size={14}/></span>Cylinders Sold</div>
          <div className="val num">{todayCyl}</div>
          <div className="sub">27 refills · {todayCyl-27} new</div>
        </div>
        <div className="stat" onClick={()=>go('customers')}>
          <div className="lbl"><span className="ic" style={{background:'var(--err-50)',color:'var(--err-600)'}}><Icon name="alert" size={14}/></span>Pending Dues</div>
          <div className="val" style={{color:'var(--err-600)'}}>{fmtINR(totalDue)}</div>
          <div className="sub">{SEED_CUSTOMERS.filter(c=>c.due>0).length} customers</div>
        </div>
      </div>

      <div style={{height: 16}}/>

      <div className="card">
        <div className="card-h"><h3>Quick Actions</h3></div>
        <div className="card-b">
          <div className="quick-actions">
            <div className="qa-btn" onClick={()=>go('newbill')}>
              <div className="ic"><Icon name="plus" size={18}/></div>
              <div><div className="t">New Bill</div><div className="s">Create & print</div></div>
            </div>
            <div className="qa-btn" onClick={()=>go('customers')}>
              <div className="ic"><Icon name="users" size={18}/></div>
              <div><div className="t">Add Customer</div><div className="s">New account</div></div>
            </div>
            <div className="qa-btn" onClick={()=>go('print')}>
              <div className="ic"><Icon name="printer" size={18}/></div>
              <div><div className="t">Print Bills</div><div className="s">9-per-page A4</div></div>
            </div>
            <div className="qa-btn" onClick={()=>go('reports')}>
              <div className="ic"><Icon name="chart" size={18}/></div>
              <div><div className="t">Today's Report</div><div className="s">Daily closing</div></div>
            </div>
          </div>
        </div>
      </div>

      <div style={{height: 16}}/>

      <div className="two-col">
        <div className="card">
          <div className="card-h">
            <h3>Sales, last 12 days</h3>
            <div className="right"><span className="badge brand">₹ thousands</span></div>
          </div>
          <div className="card-b">
            <div className="bars">
              {bars.map((v,i)=>(
                <div key={i} className={`bar ${i===bars.length-1?'today':''}`} style={{height: v*2 + 'px'}} title={`₹${v}k`}/>
              ))}
            </div>
            <div className="flex" style={{justifyContent:'space-between', color:'var(--text-3)', fontSize:11, marginTop:4}}>
              <span>9 Apr</span><span>15 Apr</span><span>20 Apr</span>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-h">
            <h3>Recent bills</h3>
            <div className="right"><button className="btn ghost sm" onClick={()=>go('bills')}>View all <Icon name="chevright" size={12}/></button></div>
          </div>
          <div style={{padding:0}}>
            <div className="tbl-wrap" style={{border:0, borderRadius:0}}>
              <table className="tbl">
                <thead><tr>
                  <th>Bill #</th><th>Customer</th><th>Mode</th><th className="num">Amount</th>
                </tr></thead>
                <tbody>
                  {recent.slice(0,6).map(b=>(
                    <tr key={b.id} className="clickable">
                      <td className="mono">#{b.id}</td>
                      <td>
                        <div style={{fontWeight:600}}>{b.cust.name}</div>
                        <div className="sub">{b.cust.village}</div>
                      </td>
                      <td><span className={`badge ${b.mode==='Credit'?'warn':b.paid===b.total?'ok':'muted'}`}>{b.mode}</span></td>
                      <td className="num" style={{fontWeight:700}}>{fmtINR(b.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div style={{height: 16}}/>

      <div className="two-col">
        <div className="card">
          <div className="card-h">
            <h3>Outstanding dues</h3>
            <div className="right"><button className="btn ghost sm" onClick={()=>go('customers')}>All <Icon name="chevright" size={12}/></button></div>
          </div>
          <div style={{padding:'4px 0'}}>
            {topOutstanding.map(c => (
              <div className="l-row" key={c.id}>
                <div className="avatar">{initials(c.name)}</div>
                <div>
                  <div className="t">{c.name}</div>
                  <div className="s">{c.village} · {c.mobile}</div>
                </div>
                <div className="amt" style={{color:'var(--err-600)'}}>{fmtINR(c.due)}</div>
                <div className="act">
                  <button className="icon-btn-s" title="Call"><Icon name="phone" size={14}/></button>
                  <button className="icon-btn-s" title="WhatsApp"><Icon name="message" size={14}/></button>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="card">
          <div className="card-h">
            <h3>Empty bottles pending</h3>
            <div className="right"><span className="badge warn">{topEmpty.reduce((s,c)=>s+c.empty,0)} bottles</span></div>
          </div>
          <div style={{padding:'4px 0'}}>
            {topEmpty.map(c => (
              <div className="l-row" key={c.id}>
                <div className="avatar">{initials(c.name)}</div>
                <div>
                  <div className="t">{c.name}</div>
                  <div className="s">{c.village} · {c.mobile}</div>
                </div>
                <div className="amt">
                  <span style={{color:'var(--warn-700)'}}>{c.empty}</span>
                  <span className="muted small" style={{fontWeight:400}}> bottles</span>
                </div>
                <div className="act">
                  <button className="icon-btn-s" title="Call"><Icon name="phone" size={14}/></button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

window.Dashboard = Dashboard;
