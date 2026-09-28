// src/App.jsx
import React, { useState, useEffect } from 'react';
import EmployeeDashboard from './components/EmployeeDashboard';
import ProfileSettings from './components/ProfileSettings';
import AdminPanel from './components/AdminPanel';
import MyProfile from './components/MyProfile';
import { API_BASE } from './config';

export default function App() {
  const [token, setToken] = useState('');
  const [user, setUser] = useState(null);
  const [isHrManager, setIsHrManager] = useState(false);
  const [activeTab, setActiveTab] = useState('dashboard'); // Default to home portal layout
  const [isRestoring, setIsRestoring] = useState(true);

  // Auth Form State
  const [isRegistering, setIsRegistering] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');

  const [authMessage, setAuthMessage] = useState('');
  const [isError, setIsError] = useState(false);

  // Restore session from a stored token on page load/refresh
  useEffect(() => {
    const storedToken = localStorage.getItem('token');
    if (!storedToken) {
      setIsRestoring(false);
      return;
    }

    const restoreSession = async () => {
      try {
        const response = await fetch(`${API_BASE}/profile/me/`, {
          headers: { 'Authorization': `Basic ${storedToken}` }
        });
        const data = await response.json();
        if (response.ok) {
          setToken(storedToken);
          setUser({ username: data.username, bio: data.bio, phone_number: data.phone_number });
          setIsHrManager(data.is_hr_manager);
        } else {
          localStorage.removeItem('token');
        }
      } catch (err) {
        localStorage.removeItem('token');
      } finally {
        setIsRestoring(false);
      }
    };

    restoreSession();
  }, []);

  const handleAuthSubmit = async (e) => {
    if (e) e.preventDefault();
    setAuthMessage('');
    setIsError(false);

    if (isRegistering) {
      // REGISTRATION HANDLER FUNCTIONALITY
      try {
        const response = await fetch(`${API_BASE}/register/`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password, email })
        });
        const data = await response.json();

        if (response.ok) {
          setAuthMessage("Registration complete! Enter credentials to authenticate session.");
          setIsRegistering(false); // Transitions view to login automatically
          setPassword('');
        } else {
          setIsError(true);
          setAuthMessage(data.error || 'Registration validation rejected.');
        }
      } catch (err) {
        setIsError(true);
        setAuthMessage('Could not reach backend API server.');
      }
    } else {
      // LOGIN HANDLER FUNCTIONALITY
      try {
        const credentials = btoa(`${username}:${password}`);
        const response = await fetch(`${API_BASE}/profile/me/`, {
          method: 'PATCH',
          headers: {
            'Authorization': `Basic ${credentials}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({}) // Initial fetch query to poll model data definitions
        });

        const data = await response.json();
        if (response.ok) {
          setToken(credentials);
          localStorage.setItem('token', credentials);
          setUser({ username, bio: "Standard worker.", phone_number: "" });
          setIsHrManager(data.is_hr_manager);
          setActiveTab('dashboard'); // Routes successfully directly to the main HR portal layout!
        } else {
          setIsError(true);
          setAuthMessage('Login failed! Invalid login credentials.');
        }
      } catch (err) {
        setIsError(true);
        setAuthMessage('Login failed! Invalid login credentials.');
      }
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken('');
    setUser(null);
    setIsHrManager(false);
    setActiveTab('dashboard');
  };

  if (isRestoring) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center">
        <p className="text-slate-400 text-sm">Loading...</p>
      </div>
    );
  }

  if (!token) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center px-4">
        <div className="max-w-md w-full bg-white p-8 rounded-xl shadow-2xl">
          <h2 className="text-3xl font-extrabold text-slate-800 text-center mb-2">StaffSync Portal</h2>
          <p className="text-sm text-slate-500 text-center mb-6">
            {isRegistering ? 'Provision a corporate node account' : 'Authenticate credentials'}
          </p>

          {authMessage && (
            <div className={`mb-4 text-sm font-semibold p-3 rounded text-center ${isError ? 'text-red-600 bg-red-50' : 'text-green-600 bg-green-50'}`}>
              {authMessage}
            </div>
          )}

          <form onSubmit={handleAuthSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-700">Username</label>
              <input type="text" value={username} onChange={(e) => setUsername(e.target.value)} required className="mt-1 w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-indigo-500 focus:outline-none" />
            </div>
            {isRegistering && (
              <div>
                <label className="block text-sm font-semibold text-slate-700">Corporate Email</label>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} className="mt-1 w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-indigo-500 focus:outline-none" />
              </div>
            )}
            <div>
              <label className="block text-sm font-semibold text-slate-700">Password</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required className="mt-1 w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-indigo-500 focus:outline-none" />
            </div>

            <button
              type="button"
              onClick={() => handleAuthSubmit()}
              className="w-full bg-indigo-600 hover:bg-indigo-750 text-white font-bold py-2 rounded transition shadow-md cursor-pointer"
            >
              {isRegistering ? 'Register Account' : 'Sign In'}
            </button>
          </form>

          <div className="mt-6 text-center border-t pt-4">
            <button
              type="button"
              onClick={() => { setIsRegistering(!isRegistering); setAuthMessage(''); }}
              className="text-sm font-medium text-indigo-600 hover:text-indigo-800 transition focus:outline-none cursor-pointer"
            >
              {isRegistering ? 'Access standard user terminal? Log In' : "New installation outpost? Register your profile"}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-100 font-sans">
      <nav className="bg-slate-800 text-white p-4 shadow-md flex justify-between items-center">
        <span className="font-bold text-xl tracking-wide text-indigo-400">StaffSync Portal</span>
        <div className="space-x-2 md:space-x-4">
          <button onClick={() => setActiveTab('dashboard')} className={`px-3 py-2 rounded font-medium transition cursor-pointer ${activeTab === 'dashboard' ? 'bg-slate-700 text-indigo-300' : 'hover:bg-slate-700'}`}>Workspace Home</button>
          <button onClick={() => setActiveTab('profile')} className={`px-3 py-2 rounded font-medium transition cursor-pointer ${activeTab === 'profile' ? 'bg-slate-700 text-indigo-300' : 'hover:bg-slate-700'}`}>My Settings</button>
          <button onClick={() => setActiveTab('myprofile')} className={`px-3 py-2 rounded font-medium transition cursor-pointer ${activeTab === 'myprofile' ? 'bg-slate-700 text-indigo-300' : 'hover:bg-slate-700'}`}>My Profile</button>
          {/* Dynamic kill chain gate validation */}
          {isHrManager && (
            <button onClick={() => setActiveTab('admin')} className={`px-3 py-2 rounded font-medium text-yellow-400 border border-yellow-500/50 transition cursor-pointer bg-amber-950/20 hover:bg-slate-700`}>Admin Controls</button>
          )}
          <button onClick={handleLogout} className="px-3 py-2 rounded font-medium text-red-300 hover:bg-slate-700 transition cursor-pointer">Log Out</button>
        </div>
      </nav>

      <main className="p-6">
        {activeTab === 'dashboard' && <EmployeeDashboard user={user} />}
        {activeTab === 'profile' && <ProfileSettings user={user} token={token} onUpdateSuccess={(status) => setIsHrManager(status)} />}
        {activeTab === 'admin' && <AdminPanel token={token} />}
        {activeTab === 'myprofile' && <MyProfile token={token} />}
      </main>
    </div>
  );
}