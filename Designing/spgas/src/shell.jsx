const Shell = ({ children, route, go, density, theme, brand, sidebar, setTweaks }) => {
  const nav = [
    ['dashboard','Dashboard','dashboard'],
    ['newbill','New Bill','plus'],
    ['customers','Customers','users'],
    ['bills','Bills','doc'],
    ['products','Products','cylinder'],
    ['print','Print 9-per-page','printer'],
    ['reports','Reports','chart'],
    ['settings','Settings','gear'],
  ];
  return (
    <div className="app" data-sidebar={sidebar}>
      <div className="topbar">
        <div className="brand">
          <div className="logo">SP</div>
          {sidebar === 'full' && <div className="name">S. P. Gas Agency<small>Himatnagar</small></div>}
        </div>
        <div className="search">
          <span className="s-icon"><Icon name="search" size={16}/></span>
          <input placeholder="Search customers, bills, products…"/>
          <span className="kbd">⌘K</span>
        </div>
        <div className="spacer"/>
        <button className="icon-btn" title="Notifications"><Icon name="bell" size={18}/><span className="dot"/></button>
        <button className="icon-btn" title="Help"><Icon name="alert" size={18}/></button>
        <div className="user">
          <div className="avatar">SP</div>
          <div style={{lineHeight:1.1}}>
            <div style={{fontSize:13, fontWeight:600}}>S. P. Patel</div>
            <div style={{fontSize:11, color:'var(--text-2)'}}>Owner</div>
          </div>
          <Icon name="chevdown" size={12} style={{color:'var(--text-3)'}}/>
        </div>
      </div>

      <div className="sidebar">
        <div className="group-label">Main</div>
        {nav.slice(0,1).map(([k,l,ic])=>(
          <div key={k} className={`nav-item ${route===k?'active':''}`} onClick={()=>go(k)} title={l}>
            <Icon name={ic} size={16}/> <span className="label">{l}</span>
          </div>
        ))}
        <div className="group-label">Operations</div>
        {nav.slice(1,6).map(([k,l,ic])=>{
          const counts = {newbill:null, customers:SEED_CUSTOMERS.length, bills:SEED_BILLS.length, products:null, print:null};
          return (
            <div key={k} className={`nav-item ${route===k?'active':''}`} onClick={()=>go(k)} title={l}>
              <Icon name={ic} size={16}/> <span className="label">{l}</span>
              {counts[k] != null && <span className="count">{counts[k]}</span>}
            </div>
          );
        })}
        <div className="group-label">Insights</div>
        {nav.slice(6).map(([k,l,ic])=>(
          <div key={k} className={`nav-item ${route===k?'active':''}`} onClick={()=>go(k)} title={l}>
            <Icon name={ic} size={16}/> <span className="label">{l}</span>
          </div>
        ))}
      </div>

      <div className="main">
        {children}
      </div>

      <div className="statusbar">
        <span className="pill"><span className="dot"/>Online</span>
        <span>Last sync: 2 minutes ago</span>
        <span>· 1,523 customers · 842 bills this month</span>
        <div className="spacer"/>
        <span>v1.0.0 · {sidebar==='full'?'Full sidebar':'Icon-only'} · {density} · {theme}</span>
      </div>
    </div>
  );
};

const TweakPanel = ({ tweaks, setTweaks }) => {
  const [open, setOpen] = useState(false);
  const set = (k, v) => {
    setTweaks(t => ({ ...t, [k]: v }));
    window.parent.postMessage({ type: '__edit_mode_set_keys', edits: { [k]: v } }, '*');
  };
  const brands = [
    ['indigo','#4f46e5'],['blue','#2563eb'],['teal','#0d9488'],
    ['emerald','#059669'],['rose','#e11d48'],['amber','#d97706'],['slate','#475569']
  ];
  return (
    <div className={`tweak-panel ${open?'open':''}`}>
      <div className="th" onClick={()=>setOpen(o=>!o)}>
        <Icon name="palette" size={14}/>
        <h4>Tweaks</h4>
        <Icon name="chevup" size={14} className="chev"/>
      </div>
      <div className="tb">
        <div className="tw-row">
          <div className="k">Brand color</div>
          <div className="swatches">
            {brands.map(([name, hex]) => (
              <div key={name} className={`swatch ${tweaks.brand===name?'on':''}`} style={{background:hex}} onClick={()=>set('brand', name)} title={name}/>
            ))}
          </div>
        </div>
        <div className="tw-row">
          <div className="k">Density</div>
          <Segmented options={[{value:'comfortable',label:'Comfortable'},{value:'compact',label:'Compact'}]} value={tweaks.density} onChange={v=>set('density',v)}/>
        </div>
        <div className="tw-row">
          <div className="k">Theme</div>
          <Segmented options={[{value:'light',label:'Light'},{value:'dark',label:'Dark'}]} value={tweaks.theme} onChange={v=>set('theme',v)}/>
        </div>
        <div className="tw-row">
          <div className="k">Sidebar</div>
          <Segmented options={[{value:'full',label:'Full'},{value:'icon',label:'Icon-only'}]} value={tweaks.sidebar} onChange={v=>set('sidebar',v)}/>
        </div>
      </div>
    </div>
  );
};

window.Shell = Shell;
window.TweakPanel = TweakPanel;
