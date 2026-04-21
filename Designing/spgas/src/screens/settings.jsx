const SettingsScreen = () => {
  const [tab, setTab] = useState('business');
  const tabs = [
    ['business','Business Profile','user'],
    ['bill','Bill Settings','doc'],
    ['users','Users & Roles','users'],
    ['backup','Backup & Restore','save'],
    ['prefs','Preferences','gear'],
    ['about','About','box'],
  ];

  return (
    <div className="page">
      <div className="page-h">
        <div><h1>Settings</h1><div className="sub">Configure your business, users and preferences</div></div>
      </div>

      <div style={{display:'grid', gridTemplateColumns:'240px 1fr', gap:16}}>
        <div className="card" style={{padding:8, height:'fit-content'}}>
          {tabs.map(([k,l,ic])=>(
            <div key={k} className={`nav-item ${tab===k?'active':''}`} onClick={()=>setTab(k)} style={{position:'relative'}}>
              <Icon name={ic} size={16}/> <span className="label">{l}</span>
            </div>
          ))}
        </div>

        <div className="card pad">
          {tab === 'business' && (
            <>
              <h3 style={{margin:'0 0 16px', fontSize:16}}>Business Profile</h3>
              <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:16}}>
                <Field label="Business Name" required><input className="input" defaultValue="S. P. Gas Agency"/></Field>
                <Field label="Proprietor"><input className="input" defaultValue="S. P. Patel"/></Field>
                <Field label="GSTIN"><input className="input mono" defaultValue="24AAUFS0029D1ZD"/></Field>
                <Field label="Phone"><input className="input" defaultValue="02772 245292"/></Field>
                <Field label="Address" required><textarea defaultValue="Nr. Hathmati Bridge, Ider Highway Road, Himatnagar - 383001"/></Field>
                <div className="field">
                  <label>Logo</label>
                  <div style={{height:100, border:'2px dashed var(--border-strong)', borderRadius:'var(--r-md)', display:'grid', placeItems:'center', color:'var(--text-2)', cursor:'pointer'}}>
                    <div style={{textAlign:'center'}}>
                      <Icon name="upload" size={20}/>
                      <div className="small mt-4">Click to upload · PNG, JPG up to 2MB</div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="flex" style={{justifyContent:'flex-end', gap:8, marginTop:20, paddingTop:20, borderTop:'1px solid var(--divider)'}}>
                <button className="btn secondary">Cancel</button>
                <button className="btn primary"><Icon name="save" size={14}/> Save Changes</button>
              </div>
            </>
          )}
          {tab === 'bill' && (
            <>
              <h3 style={{margin:'0 0 16px', fontSize:16}}>Bill Settings</h3>
              <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:16}}>
                <Field label="Bill Number Prefix"><input className="input" defaultValue="SPG-"/></Field>
                <Field label="Starting Number"><input className="input" type="number" defaultValue="2448"/></Field>
                <Field label="Default GST (%)"><input className="input" type="number" defaultValue="5"/></Field>
                <Field label="Rounding"><select className="select"><option>Nearest rupee</option><option>Nearest 10 paise</option><option>No rounding</option></select></Field>
                <Field label="Date Format"><select className="select"><option>DD-MMM-YYYY</option><option>DD/MM/YYYY</option></select></Field>
                <Field label="Financial Year Start"><select className="select"><option>April</option><option>January</option></select></Field>
              </div>
              <div className="hline mt-16"/>
              <div className="mt-16">
                <div style={{fontWeight:600, marginBottom:12}}>Print template</div>
                <div style={{display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:12}}>
                  {['Single A4','Half A4','9-per-page'].map((t,i)=>(
                    <div key={t} style={{padding:16, border:'2px solid', borderColor: i===2?'var(--brand-500)':'var(--border)', borderRadius:'var(--r-md)', cursor:'pointer', textAlign:'center'}}>
                      <div style={{height:60, background:'var(--surface-2)', borderRadius:4, marginBottom:8, display:'grid', placeItems:'center'}}>
                        <Icon name="doc" size={20}/>
                      </div>
                      <div style={{fontWeight:600, fontSize:13}}>{t}</div>
                      {i===2 && <div className="badge brand mt-4">Default</div>}
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}
          {tab === 'users' && (
            <>
              <h3 style={{margin:'0 0 16px', fontSize:16}}>Users & Roles</h3>
              <div className="tbl-wrap">
                <table className="tbl">
                  <thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Last active</th><th></th></tr></thead>
                  <tbody>
                    <tr><td style={{fontWeight:600}}>S. P. Patel</td><td className="mono small">owner@spgas</td><td><span className="badge brand">Admin</span></td><td className="muted small">Just now</td><td><button className="icon-btn-s"><Icon name="more" size={14}/></button></td></tr>
                    <tr><td style={{fontWeight:600}}>Kiran (Counter)</td><td className="mono small">kiran@spgas</td><td><span className="badge muted">Billing Staff</span></td><td className="muted small">2h ago</td><td><button className="icon-btn-s"><Icon name="more" size={14}/></button></td></tr>
                    <tr><td style={{fontWeight:600}}>Amit (Delivery)</td><td className="mono small">amit@spgas</td><td><span className="badge muted">Delivery</span></td><td className="muted small">Yesterday</td><td><button className="icon-btn-s"><Icon name="more" size={14}/></button></td></tr>
                  </tbody>
                </table>
              </div>
              <button className="btn primary mt-16"><Icon name="plus" size={14}/> Invite user</button>
            </>
          )}
          {tab === 'backup' && (
            <>
              <h3 style={{margin:'0 0 16px', fontSize:16}}>Backup & Restore</h3>
              <div className="card pad" style={{background:'var(--ok-50)', borderColor:'var(--ok-100)'}}>
                <div className="flex center gap-12">
                  <div style={{width:36, height:36, borderRadius:8, background:'var(--ok-500)', color:'white', display:'grid', placeItems:'center'}}><Icon name="check" size={18} stroke={3}/></div>
                  <div style={{flex:1}}>
                    <div style={{fontWeight:700}}>Last backup: 2 minutes ago</div>
                    <div className="small muted">Auto-sync to cloud enabled · 47 MB · Encrypted</div>
                  </div>
                  <button className="btn secondary sm">Backup now</button>
                </div>
              </div>
              <div className="mt-16">
                <label className="checkbox"><input type="checkbox" defaultChecked/><span className="box"/>Auto-backup every 30 minutes</label><br/><br/>
                <label className="checkbox"><input type="checkbox" defaultChecked/><span className="box"/>Encrypt backups with password</label><br/><br/>
                <label className="checkbox"><input type="checkbox"/><span className="box"/>Include attached documents</label>
              </div>
            </>
          )}
          {tab === 'prefs' && (
            <>
              <h3 style={{margin:'0 0 16px', fontSize:16}}>Preferences</h3>
              <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:16}}>
                <Field label="Language"><select className="select"><option>English</option><option>ગુજરાતી (Gujarati)</option><option>हिन्दी (Hindi)</option></select></Field>
                <Field label="Theme"><select className="select"><option>Light</option><option>Dark</option><option>Auto</option></select></Field>
                <Field label="Density"><select className="select"><option>Comfortable</option><option>Compact</option></select></Field>
                <Field label="Currency Symbol"><select className="select"><option>₹ (Rupee)</option></select></Field>
              </div>
              <div className="hline mt-16"/>
              <div className="mt-16" style={{fontWeight:600, marginBottom:8}}>Keyboard shortcuts</div>
              <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8, fontSize:13}}>
                {[['New bill','F2'],['Global search','Ctrl+K'],['Save','Ctrl+S'],['Print','Ctrl+P'],['Dashboard','Ctrl+D'],['Bills','Ctrl+B']].map(([l,k])=>(
                  <div key={l} className="flex" style={{justifyContent:'space-between', padding:'6px 0'}}><span>{l}</span><Kbd k={k}/></div>
                ))}
              </div>
            </>
          )}
          {tab === 'about' && (
            <>
              <h3 style={{margin:'0 0 16px', fontSize:16}}>About</h3>
              <div className="flex center gap-12">
                <div style={{width:64, height:64, borderRadius:16, background:'linear-gradient(135deg, var(--brand-600), var(--brand-800))', color:'white', display:'grid', placeItems:'center', fontWeight:800, fontSize:22}}>SP</div>
                <div>
                  <div style={{fontSize:18, fontWeight:700}}>S. P. Gas Agency — Billing</div>
                  <div className="muted small">Version 1.0.0 · Build 2026.04.20</div>
                  <div className="small mt-4">License: Perpetual · Activated for S. P. Gas Agency</div>
                </div>
              </div>
              <div className="hline mt-16"/>
              <div className="mt-16 small muted" style={{lineHeight:1.7}}>
                Built for Indian gas distribution businesses. Works offline. Syncs when online.
                Supports multiple users, roles, and locations. Full GSTIN compliance.
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

window.SettingsScreen = SettingsScreen;
