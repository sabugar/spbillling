// Shared UI atoms
const { useState, useEffect, useRef, useMemo, useCallback, createContext, useContext } = React;

// Toast system
const ToastCtx = createContext(null);
const useToast = () => useContext(ToastCtx);

const ToastProvider = ({ children }) => {
  const [toasts, setToasts] = useState([]);
  const push = (t) => {
    const id = Math.random().toString(36).slice(2);
    setToasts(ts => [...ts, { id, ...t }]);
    setTimeout(() => setToasts(ts => ts.filter(x => x.id !== id)), t.duration || 4000);
  };
  const dismiss = (id) => setToasts(ts => ts.filter(x => x.id !== id));
  return (
    <ToastCtx.Provider value={{ push }}>
      {children}
      <div className="toasts">
        {toasts.map(t => (
          <div key={t.id} className={`toast ${t.kind||'ok'}`}>
            <div className="ic">
              <Icon name={t.kind==='err'?'x':t.kind==='warn'?'alert':'check'} size={14} stroke={3} />
            </div>
            <div style={{flex:1}}>
              <div className="title">{t.title}</div>
              {t.msg && <div className="msg">{t.msg}</div>}
            </div>
            <button className="close" onClick={()=>dismiss(t.id)}><Icon name="x" size={14}/></button>
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
};

// Modal
const Modal = ({ title, onClose, children, footer, width }) => (
  <div className="modal-backdrop" onClick={(e)=>{ if(e.target===e.currentTarget) onClose?.(); }}>
    <div className="modal" style={width ? {width} : undefined}>
      <div className="m-h">
        <h3>{title}</h3>
        <button className="icon-btn-s close" onClick={onClose}><Icon name="x" size={14}/></button>
      </div>
      <div className="m-b">{children}</div>
      {footer && <div className="m-f">{footer}</div>}
    </div>
  </div>
);

// Drawer (right side)
const Drawer = ({ onClose, children, width }) => (
  <>
    <div className="drawer-backdrop" onClick={onClose}/>
    <div className="drawer" style={width ? {width} : undefined}>
      {children}
    </div>
  </>
);

// Segmented
const Segmented = ({ options, value, onChange }) => (
  <div className="seg">
    {options.map(o => (
      <button key={o.value} className={value===o.value?'on':''} onClick={()=>onChange(o.value)}>
        {o.label}
      </button>
    ))}
  </div>
);

// Field
const Field = ({ label, required, error, help, children }) => (
  <div className={`field ${error?'error':''}`}>
    <label>{label}{required && <span className="req">*</span>}</label>
    {children}
    {(error || help) && <div className="help">{error || help}</div>}
  </div>
);

// Small helpers
const Kbd = ({ k }) => <span className="kbd-hint">{k}</span>;

// Highlight substring in text
const highlight = (text, q) => {
  if (!q) return text;
  const idx = text.toLowerCase().indexOf(q.toLowerCase());
  if (idx === -1) return text;
  return <>{text.slice(0,idx)}<mark>{text.slice(idx, idx+q.length)}</mark>{text.slice(idx+q.length)}</>;
};

Object.assign(window, { ToastCtx, useToast, ToastProvider, Modal, Drawer, Segmented, Field, Kbd, highlight });
