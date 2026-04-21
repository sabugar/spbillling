const LoginScreen = ({ onLogin }) => {
  const [user, setUser] = useState('owner@spgas');
  const [pwd, setPwd] = useState('demo1234');
  const [show, setShow] = useState(false);
  const [remember, setRemember] = useState(true);
  const [loading, setLoading] = useState(false);
  const submit = (e) => {
    e.preventDefault();
    setLoading(true);
    setTimeout(() => onLogin(), 600);
  };
  return (
    <div className="login-wrap">
      <div className="login-side">
        <div className="logo-big">
          <div className="lm">SP</div>
          <div>
            <div style={{fontWeight:700, fontSize:16, letterSpacing:'-0.01em'}}>S. P. Gas Agency</div>
            <div style={{fontSize:12, opacity:.8}}>Authorised Distributors · Himatnagar</div>
          </div>
        </div>
        <div>
          <h2>Fast billing.<br/>Clear books.<br/>Every day.</h2>
          <p>Built for the counter — create bills in seconds, track dues and empty cylinders across all your customers, and print 9 bills to a page for quick delivery.</p>
        </div>
        <div className="stamp">
          <div className="k">Today's snapshot</div>
          <div className="v">₹48,920 · 34 bills · 52 cylinders</div>
        </div>
      </div>

      <div className="login-form-wrap">
        <form className="login-form" onSubmit={submit}>
          <h1>Sign in</h1>
          <p className="sub">Welcome back. Enter your credentials to continue.</p>

          <div style={{display:'flex',flexDirection:'column',gap:14}}>
            <Field label="Username or mobile" required>
              <div className="input-with-icon">
                <span className="ii"><Icon name="user" size={16}/></span>
                <input className="input" value={user} onChange={e=>setUser(e.target.value)} autoFocus/>
              </div>
            </Field>

            <Field label="Password" required>
              <div className="input-with-icon">
                <span className="ii"><Icon name="gear" size={16}/></span>
                <input className="input" type={show?'text':'password'} value={pwd} onChange={e=>setPwd(e.target.value)}/>
                <span className="clear" onClick={()=>setShow(s=>!s)}>
                  <Icon name={show?'eyeoff':'eye'} size={16}/>
                </span>
              </div>
            </Field>

            <div className="flex" style={{justifyContent:'space-between',alignItems:'center'}}>
              <label className="checkbox">
                <input type="checkbox" checked={remember} onChange={e=>setRemember(e.target.checked)}/>
                <span className="box"/>
                <span>Remember me</span>
              </label>
              <a href="#" style={{color:'var(--brand-600)', fontSize:13, fontWeight:600, textDecoration:'none'}}>Forgot password?</a>
            </div>

            <button className="btn primary lg block" type="submit" disabled={loading}>
              {loading ? 'Signing in…' : 'Sign in'}
            </button>
          </div>

          <div className="mt-24 muted small" style={{textAlign:'center'}}>
            <span className="flex center gap-6" style={{justifyContent:'center'}}>
              <Icon name="wifi" size={12}/> Works offline · Auto-syncs when online
            </span>
          </div>
        </form>
      </div>
    </div>
  );
};

window.LoginScreen = LoginScreen;
