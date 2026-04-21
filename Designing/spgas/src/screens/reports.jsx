const ReportsScreen = () => {
  const [active, setActive] = useState('sales');
  const reports = [
    ['Sales', [['sales','Daily Sales'], ['monthly','Monthly Summary'], ['product','Sales by Product'], ['cust','Sales by Customer']]],
    ['Receivables', [['outstanding','Outstanding Dues'], ['aging','Ageing Analysis'], ['collections','Collections']]],
    ['Inventory', [['stock','Stock Position'], ['empty','Empty Bottle Ledger']]],
    ['GST', [['gstr1','GSTR-1'], ['hsn','HSN Summary']]],
  ];

  // Simple SVG line + bar chart
  const data = [32, 41, 35, 48, 52, 44, 58, 49, 62, 55, 68, 61, 72, 66];
  const max = Math.max(...data);
  const pts = data.map((v,i)=>`${(i/(data.length-1))*780+20},${180-(v/max)*140+20}`).join(' ');

  return (
    <div className="page">
      <div className="page-h">
        <div><h1>Reports</h1><div className="sub">Business performance & analytics</div></div>
        <div className="right">
          <Segmented options={[{value:'7',label:'7D'},{value:'30',label:'30D'},{value:'90',label:'90D'},{value:'ytd',label:'YTD'}]} value="30" onChange={()=>{}}/>
          <button className="btn secondary"><Icon name="download" size={14}/> Export</button>
          <button className="btn secondary"><Icon name="printer" size={14}/> Print</button>
        </div>
      </div>

      <div className="rep-grid">
        <div className="rep-list">
          {reports.map(([cat, items]) => (
            <React.Fragment key={cat}>
              <div className="rep-cat">{cat}</div>
              {items.map(([id, label]) => (
                <div key={id} className={`rep-item ${active===id?'on':''}`} onClick={()=>setActive(id)}>{label}</div>
              ))}
            </React.Fragment>
          ))}
        </div>

        <div>
          <div className="stat-grid" style={{gridTemplateColumns:'repeat(4,1fr)'}}>
            <div className="stat"><div className="lbl">Total Sales</div><div className="val">{fmtINR(762450)}</div><div className="sub">30 days · <span className="delta up"><Icon name="arrowup" size={10}/>18%</span></div></div>
            <div className="stat"><div className="lbl">Bills Generated</div><div className="val num">842</div><div className="sub">Avg 28/day</div></div>
            <div className="stat"><div className="lbl">Cylinders Moved</div><div className="val num">1,284</div><div className="sub">72% refill · 28% new</div></div>
            <div className="stat"><div className="lbl">Collection Rate</div><div className="val">94.2%</div><div className="sub">₹44,180 outstanding</div></div>
          </div>

          <div className="chart mt-16">
            <div className="flex" style={{justifyContent:'space-between', marginBottom:10}}>
              <div><div style={{fontSize:13, fontWeight:600}}>Daily sales trend</div><div className="small muted">Last 14 days</div></div>
              <div className="flex gap-12 small muted">
                <span className="flex center gap-4"><span style={{width:10,height:10,borderRadius:2,background:'var(--brand-500)'}}/>This period</span>
              </div>
            </div>
            <svg className="chart-svg" viewBox="0 0 820 220" preserveAspectRatio="none">
              <defs>
                <linearGradient id="gr" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0" stopColor="var(--brand-500)" stopOpacity=".25"/>
                  <stop offset="1" stopColor="var(--brand-500)" stopOpacity="0"/>
                </linearGradient>
              </defs>
              {[0,1,2,3].map(i=>(
                <line key={i} x1="20" x2="800" y1={20+i*47} y2={20+i*47} stroke="var(--divider)" strokeWidth="1"/>
              ))}
              <polyline points={`20,200 ${pts} 800,200`} fill="url(#gr)" stroke="none"/>
              <polyline points={pts} fill="none" stroke="var(--brand-600)" strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round"/>
              {data.map((v,i)=>(
                <circle key={i} cx={(i/(data.length-1))*780+20} cy={180-(v/max)*140+20} r="3.5" fill="white" stroke="var(--brand-600)" strokeWidth="2"/>
              ))}
            </svg>
          </div>

          <div className="card mt-16">
            <div className="card-h"><h3>Top performing customers</h3><div className="right"><button className="btn ghost sm">View all <Icon name="chevright" size={12}/></button></div></div>
            <div className="tbl-wrap" style={{border:0, borderRadius:0}}>
              <table className="tbl">
                <thead><tr><th>#</th><th>Customer</th><th>Village</th><th className="num">Bills</th><th className="num">Revenue</th><th style={{width:120}}>Share</th></tr></thead>
                <tbody>
                  {[...SEED_CUSTOMERS].sort((a,b)=>b.business-a.business).slice(0,6).map((c,i)=>{
                    const pct = Math.round(c.business/147000*100);
                    return (
                      <tr key={c.id}>
                        <td style={{color:'var(--text-3)'}}>{i+1}</td>
                        <td style={{fontWeight:600}}>{c.name}</td>
                        <td className="muted">{c.village}</td>
                        <td className="num">{Math.round(c.business/1500)}</td>
                        <td className="num" style={{fontWeight:600}}>{fmtINR(c.business)}</td>
                        <td>
                          <div style={{height:6, background:'var(--surface-2)', borderRadius:3, overflow:'hidden'}}>
                            <div style={{height:'100%', width:pct+'%', background:'var(--brand-500)'}}/>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

window.ReportsScreen = ReportsScreen;
