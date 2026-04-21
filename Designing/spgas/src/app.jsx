const App = () => {
  // Load tweak defaults
  const defaultsEl = document.getElementById('editmode-defaults');
  let defaults = { brand:'indigo', density:'comfortable', theme:'light', sidebar:'full' };
  try {
    const m = defaultsEl.textContent.match(/\/\*EDITMODE-BEGIN\*\/([\s\S]*?)\/\*EDITMODE-END\*\//);
    if (m) defaults = JSON.parse(m[1]);
  } catch (e) {}

  const [tweaks, setTweaks] = useState(defaults);
  const [route, setRoute] = useState(() => localStorage.getItem('spgas-route') || 'login');
  const [selectedCustomer, setSelectedCustomer] = useState(null);
  const [preselectedCustomer, setPreselectedCustomer] = useState(null);
  const [printIds, setPrintIds] = useState([]);
  const toast = useToast();

  // Apply theme/density/brand to html
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', tweaks.theme);
    document.documentElement.setAttribute('data-density', tweaks.density);
    document.documentElement.setAttribute('data-brand', tweaks.brand);
  }, [tweaks]);

  useEffect(() => { localStorage.setItem('spgas-route', route); }, [route]);

  // Edit mode wiring
  useEffect(() => {
    const onMsg = (e) => {
      if (!e.data || !e.data.type) return;
      if (e.data.type === '__activate_edit_mode') document.querySelector('.tweak-panel')?.classList.add('open');
      if (e.data.type === '__deactivate_edit_mode') document.querySelector('.tweak-panel')?.classList.remove('open');
    };
    window.addEventListener('message', onMsg);
    window.parent.postMessage({ type: '__edit_mode_available' }, '*');
    return () => window.removeEventListener('message', onMsg);
  }, []);

  // Global keyboard shortcuts
  useEffect(() => {
    if (route === 'login') return;
    const handler = (e) => {
      if (e.key === 'F2') { e.preventDefault(); setRoute('newbill'); }
      else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'd') { e.preventDefault(); setRoute('dashboard'); }
      else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'b') { e.preventDefault(); setRoute('bills'); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [route]);

  const go = (r, payload) => {
    if (r === 'newbill' && payload) setPreselectedCustomer(payload);
    if (r === 'print' && Array.isArray(payload)) setPrintIds(payload);
    setRoute(r);
  };
  const openCustomer = (c) => setSelectedCustomer(c);

  if (route === 'login') {
    return <LoginScreen onLogin={()=>{ setRoute('dashboard'); toast.push({kind:'ok', title:'Welcome back', msg:'Signed in as S. P. Patel'}); }}/>;
  }

  return (
    <>
      <Shell route={route} go={go} {...tweaks} setTweaks={setTweaks}>
        {route === 'dashboard'  && <Dashboard go={go}/>}
        {route === 'customers'  && <CustomersScreen openCustomer={openCustomer} go={go}/>}
        {route === 'newbill'    && <NewBillScreen toast={toast} preselected={preselectedCustomer} onSaved={()=>{ setPreselectedCustomer(null); setRoute('bills'); }}/>}
        {route === 'bills'      && <BillsScreen go={go}/>}
        {route === 'products'   && <ProductsScreen/>}
        {route === 'print'      && <PrintPreview selectedIds={printIds} go={go}/>}
        {route === 'reports'    && <ReportsScreen/>}
        {route === 'settings'   && <SettingsScreen/>}
      </Shell>
      {selectedCustomer && <CustomerDetail customer={selectedCustomer} onClose={()=>setSelectedCustomer(null)} go={(r,p)=>{ setSelectedCustomer(null); go(r,p); }}/>}
      <TweakPanel tweaks={tweaks} setTweaks={setTweaks}/>
    </>
  );
};

const Root = () => (
  <ToastProvider>
    <App/>
  </ToastProvider>
);

ReactDOM.createRoot(document.getElementById('root')).render(<Root/>);
