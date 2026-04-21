const ProductsScreen = () => {
  const [open, setOpen] = useState({'LPG Cylinder':true, 'Regulators & Accessories':true, 'Stoves':false});
  const [q, setQ] = useState('');
  return (
    <div className="page">
      <div className="page-h">
        <div><h1>Products</h1><div className="sub">{SEED_PRODUCTS.length} categories · {SEED_PRODUCTS.reduce((s,c)=>s+c.variants.length,0)} variants</div></div>
        <div className="right">
          <button className="btn secondary"><Icon name="upload" size={14}/> Import</button>
          <button className="btn primary"><Icon name="plus" size={14}/> Add Product</button>
        </div>
      </div>

      <div className="filters">
        <div className="input-with-icon" style={{flex:1, maxWidth:340}}>
          <span className="ii"><Icon name="search" size={16}/></span>
          <input className="input" placeholder="Search products…" value={q} onChange={e=>setQ(e.target.value)}/>
        </div>
        <div className="filter-chip on">All</div>
        <div className="filter-chip">Returnable</div>
        <div className="filter-chip">Low stock</div>
      </div>

      <div className="prod-tree">
        {SEED_PRODUCTS.map(grp => (
          <div key={grp.cat} className={`grp ${open[grp.cat]?'open':''}`}>
            <div className="grp-h" onClick={()=>setOpen({...open, [grp.cat]:!open[grp.cat]})}>
              <Icon name="chevright" size={14} style={{transform: open[grp.cat]?'rotate(90deg)':'none', transition:'.2s'}}/>
              <div style={{width:30, height:30, background:'var(--brand-50)', color:'var(--brand-700)', borderRadius:8, display:'grid', placeItems:'center'}}>
                <Icon name={grp.icon} size={16}/>
              </div>
              <h4>{grp.cat}</h4>
              <span className="badge muted count">{grp.variants.length} variants</span>
              <button className="btn ghost sm" onClick={e=>e.stopPropagation()}><Icon name="plus" size={12}/> Variant</button>
            </div>
            {open[grp.cat] && (
              <table className="v-tbl">
                <thead><tr>
                  <th>Variant</th><th>Size</th><th className="num">Unit Price</th><th className="num">Deposit</th>
                  <th>Returnable</th><th className="num">GST</th><th className="num">Stock</th><th style={{width:40}}></th>
                </tr></thead>
                <tbody>
                  {grp.variants.map(v => (
                    <tr key={v.id}>
                      <td style={{fontWeight:600}}>{v.name}</td>
                      <td className="muted">{v.size}</td>
                      <td className="num" style={{fontWeight:600}}>{fmtINR(v.price)}</td>
                      <td className="num muted">{v.deposit>0?fmtINR(v.deposit):'—'}</td>
                      <td>{v.returnable ? <span className="badge ok"><Icon name="check" size={10} stroke={3}/> Yes</span> : <span className="badge muted">No</span>}</td>
                      <td className="num">{v.gst}%</td>
                      <td className="num">
                        <span className={`badge ${v.stock<10?'err':v.stock<30?'warn':'ok'}`}>{v.stock}</span>
                      </td>
                      <td><button className="icon-btn-s"><Icon name="more" size={14}/></button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

window.ProductsScreen = ProductsScreen;
