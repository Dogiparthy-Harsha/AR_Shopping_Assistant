import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

// Note: StrictMode removed because MediaPipe WASM doesn't support
// being initialized twice (which happens in StrictMode dev mode)
createRoot(document.getElementById('root')).render(<App />)
