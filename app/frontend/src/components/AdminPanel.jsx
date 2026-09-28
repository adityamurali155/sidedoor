import React, { useState, useEffect } from 'react';
import { API_BASE } from '../config';

export default function AdminPanel({ token }) {
  const [deptId, setDeptId] = useState(101);
  const [deptData, setDeptData] = useState(null);
  const [webhookUrl, setWebhookUrl] = useState('');
  const [ssrfResponse, setSsrfResponse] = useState('');
  const [error, setError] = useState('');
  const [integrationToken, setIntegrationToken] = useState('');

  useEffect(() => {
    const fetchDeptSettings = async () => {
      try {
        const response = await fetch(`${API_BASE}/departments/${deptId}/settings/`, {
          headers: { 'Authorization': `Basic ${token}` }
        });
        const data = await response.json();
        if (response.ok) {
          setDeptData(data);
          setError('');
        } else {
          setError(data.error || 'Failed to fetch settings');
          setDeptData(null);
        }
      } catch (err) {
        setError('Network error');
      }
    };
    fetchDeptSettings();
  }, [deptId, token]);

const triggerWebhookTest = async (e) => {
  e.preventDefault();
  try {
    const response = await fetch(`${API_BASE}/integrations/test-webhook/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${token}`
      },
      body: JSON.stringify({ webhook_url: webhookUrl, integration_token: integrationToken })
    });
    const data = await response.json();
    setSsrfResponse(JSON.stringify(data, null, 2));
  } catch (err) {
    setSsrfResponse('Failed to contact integration endpoint.');
  }
};

  return (
    <div className="max-w-4xl mx-auto mt-10 p-6 bg-slate-50 rounded-xl shadow-lg">
      <h1 className="text-3xl font-extrabold text-slate-900 border-b pb-4 mb-6">StaffSync Administration Portal</h1>
      
      <div className="bg-white p-6 rounded-lg shadow-sm mb-6 border border-slate-200">
        <h2 className="text-xl font-bold text-slate-800 mb-3">Department Config Manager</h2>
        <div className="flex items-center space-x-4 mb-4">
          <label className="text-sm font-medium text-slate-600">Active Department ID:</label>
          <input 
            type="number" value={deptId} onChange={(e) => setDeptId(e.target.value)}
            className="w-24 px-3 py-1 border border-slate-300 rounded focus:ring-2 focus:ring-blue-500"
          />
        </div>
        
        {error && <p className="text-red-500 text-sm mb-2">{error}</p>}
        {deptData && (
          <div className="bg-slate-100 p-4 rounded border border-slate-300">
            <h3 className="font-semibold text-slate-700">Viewing Data for: {deptData.department}</h3>
            <p className="mt-2 text-sm font-mono text-slate-600 bg-white p-3 rounded shadow-inner whitespace-pre-wrap">{deptData.notes}</p>
          </div>
        )}
      </div>

      <div className="bg-white p-6 rounded-lg shadow-sm border border-slate-200">
        <h2 className="text-xl font-bold text-slate-800 mb-2">Enterprise Slack Webhook Tester</h2>
        <p className="text-xs text-slate-500 mb-4">Internal utility tool for troubleshooting platform outposts. Feeds straight into internal API nodes.</p>
        
        <form onSubmit={triggerWebhookTest} className="space-y-4">
            <div>
                <input 
                type="text" placeholder="https://slack.com..." value={webhookUrl} onChange={(e) => setWebhookUrl(e.target.value)}
                className="w-full px-4 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-blue-500"
                />
            </div>
            <div>
                <input
                type="text" placeholder="Integration token..." value={integrationToken}
                onChange={(e) => setIntegrationToken(e.target.value)}
                className="w-full px-4 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-blue-500"
                />
            </div>
            <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded font-medium hover:bg-blue-700 transition">
                Fire Outbound Test Packet
            </button>
        </form>

        {ssrfResponse && (
          <div className="mt-6">
            <h3 className="text-sm font-semibold text-slate-700 mb-2">Server Response Raw Body:</h3>
            <pre className="bg-zinc-900 text-zinc-100 p-4 rounded font-mono text-xs overflow-x-auto shadow-md max-h-60">{ssrfResponse}</pre>
          </div>
        )}
      </div>
    </div>
  );
}
