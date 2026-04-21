const PrintPreview = ({ selectedIds, go }) => {
  const [page, setPage] = useState(1);
  const all = selectedIds && selectedIds.length > 0
    ? SEED_BILLS.filter(b => selectedIds.includes(b.id))
    : SEED_BILLS.slice(0, 27);
  const perPage = 9;
  const pages = Math.max(1, Math.ceil(all.length / perPage));
  const pageBills = all.slice((page-1)*perPage, page*perPage);
  while (pageBills.length < perPage) pageBills.push(null);

  return (
    <div className="page">
      <div className="page-h">
        <div><h1>Print — 9 bills per page</h1><div className="sub">A4 portrait · 3×3 layout · {all.length} bills · {pages} {pages===1?'page':'pages'}</div></div>
        <div className="right">
          <button className="btn secondary" onClick={()=>go('bills')}><Icon name="chevleft" size={14}/> Back</button>
        </div>
      </div>

      <div className="print-toolbar">
        <div className="flex gap-8 center">
          <button className="btn secondary sm" disabled={page===1} onClick={()=>setPage(p=>p-1)}><Icon name="chevleft" size={14}/></button>
          <span className="small" style={{minWidth:90, textAlign:'center'}}>Page {page} of {pages}</span>
          <button className="btn secondary sm" disabled={page===pages} onClick={()=>setPage(p=>p+1)}><Icon name="chevright" size={14}/></button>
        </div>
        <div style={{flex:1}}/>
        <button className="btn secondary sm"><Icon name="download" size={14}/> PDF</button>
        <button className="btn primary sm" onClick={()=>window.print()}><Icon name="printer" size={14}/> Print</button>
      </div>

      <div className="print-stage">
        <div className="a4">
          {pageBills.map((b, i) => b ? (
            <div className="minibill" key={b.id}>
              <div className="agency">S. P. GAS AGENCY <small>Authorised Distributors · Himatnagar</small></div>
              <div className="mb-head">
                <div className="no">BILL #{b.id}</div>
                <div className="dt">{fmtDateShort(b.date)}</div>
              </div>
              <div>
                <div className="cust">{b.cust.name}</div>
                <div className="cust-sub">{b.cust.village} · {b.cust.mobile}</div>
              </div>
              <div className="items">
                {b.items.slice(0,3).map((it,j)=>(
                  <div className="it" key={j}>
                    <span className="n">{it.prod.name} × {it.qty}</span>
                    <span className="v">{(it.prod.price*it.qty).toFixed(2)}</span>
                  </div>
                ))}
              </div>
              <div className="tot">
                <span>Total <span className="amt">₹{b.total.toLocaleString('en-IN')}</span></span>
                {b.paid >= b.total
                  ? <span className="paid-stamp">Paid</span>
                  : <span className="due-stamp">Due ₹{(b.total-b.paid).toLocaleString('en-IN')}</span>}
              </div>
            </div>
          ) : (
            <div key={'empty'+i} style={{border:'1px dashed #ccc', borderRadius:4}}/>
          ))}
        </div>
      </div>
    </div>
  );
};

window.PrintPreview = PrintPreview;
