import React, { useState } from 'react';
import { API_BASE } from '../config';

export default function ProfileSettings({ user, token, onUpdateSuccess }) {
  const formData = {
    bio: user.bio || '',
    phone_number: user.phone_number || ''
  };
  const [profileData, setProfileData] = useState(formData);
  const [message, setMessage] = useState('');

  const handleChange = (e) => {
    setProfileData({ ...profileData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch(`${API_BASE}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${token}`
        },
        body: JSON.stringify(profileData)
      });
      const data = await response.json();
      if (response.ok) {
        setMessage('Profile updated successfully!');
        onUpdateSuccess(data.is_hr_manager);
      }
    } catch (err) {
      setMessage('An error occurred updating the profile.');
    }
  };

  return (
    <div className="max-w-md mx-auto mt-10 bg-white p-8 rounded-lg shadow-md border border-gray-200">
      <h2 className="text-2xl font-bold mb-6 text-slate-800 text-center">Profile Settings</h2>
      {message && <div className="mb-4 text-sm font-semibold text-green-600 bg-green-50 p-2 rounded">{message}</div>}
      
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">Phone Number</label>
          <input 
            type="text" name="phone_number" value={profileData.phone_number} onChange={handleChange}
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Bio</label>
          <textarea 
            name="bio" value={profileData.bio} onChange={handleChange}
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
          />
        </div>
        <button type="submit" className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-750 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
          Save Settings
        </button>
      </form>
    </div>
  );
}
