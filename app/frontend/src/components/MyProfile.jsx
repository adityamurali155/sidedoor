import React, { useState, useEffect } from 'react';
import { API_BASE } from '../config';

export default function MyProfile({ token }) {
  const [profile, setProfile] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const response = await fetch(`${API_BASE}/profile/me/`, {
          headers: { 'Authorization': `Basic ${token}` }
        });
        const data = await response.json();
        if (response.ok) {
          setProfile(data);
        } else {
          setError(data.error || 'Failed to load profile');
        }
      } catch (err) {
        setError('Network error');
      }
    };
    fetchProfile();
  }, [token]);

  const initials = profile?.username
    ? profile.username.slice(0, 2).toUpperCase()
    : '??';

  return (
    <div className="max-w-md mx-auto mt-10 bg-white p-8 rounded-lg shadow-md border border-gray-200">
      {error && <p className="text-red-500 text-sm mb-4 text-center">{error}</p>}
      {profile && (
        <>
          <div className="flex flex-col items-center mb-6">
            <div className="w-24 h-24 rounded-full bg-indigo-600 text-white flex items-center justify-center text-2xl font-bold shadow-md">
              {initials}
            </div>
            <h2 className="mt-4 text-xl font-bold text-slate-800">{profile.username}</h2>
          </div>

          <div className="space-y-3 text-sm text-slate-700 border-t pt-4">
            <p><span className="font-semibold">Email:</span> {profile.email}</p>
            <p><span className="font-semibold">Bio:</span> {profile.bio}</p>
            <p><span className="font-semibold">Phone:</span> {profile.phone_number}</p>
            <p><span className="font-semibold">HR Manager:</span> {profile.is_hr_manager ? 'Yes' : 'No'}</p>
          </div>
        </>
      )}
    </div>
  );
}