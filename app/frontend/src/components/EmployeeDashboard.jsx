import React from 'react';

export default function EmployeeDashboard({ user }) {
  return (
    <div className="max-w-5xl mx-auto mt-6 space-y-6">
      {/* Welcome Banner */}
      <div className="bg-gradient-to-r from-slate-800 to-indigo-950 p-6 rounded-xl text-white shadow-md">
        <h1 className="text-3xl font-extrabold">Welcome back, {user?.username || 'Employee'}!</h1>
        <p className="text-indigo-200 mt-1 text-sm">StaffSync Network Status: Connected</p>
      </div>

      {/* Grid Content */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Profile Card */}
        <div className="bg-white p-5 rounded-lg shadow-sm border border-slate-200 flex flex-col justify-between">
          <div>
            <h2 className="font-bold text-slate-800 text-lg border-b pb-2 mb-3">Employment Profile</h2>
            <p className="text-sm text-slate-600"><span className="font-semibold">Security Clearance:</span> Low (General Access)</p>
            <p className="text-sm text-slate-600 mt-1"><span className="font-semibold">Bio Status:</span> {user?.bio || 'Standard employee.'}</p>
          </div>
          <p className="text-xs text-slate-400 mt-4 font-mono">ID: SEC-NODE-4021</p>
        </div>

        {/* Corporate Bulletins */}
        <div className="bg-white p-5 rounded-lg shadow-sm border border-slate-200 md:col-span-2">
          <h2 className="font-bold text-slate-800 text-lg border-b pb-2 mb-3">Internal Bulletins</h2>
          <div className="space-y-3">
            <div className="p-3 bg-slate-50 border-l-4 border-indigo-500 rounded-r">
              <span className="text-xs text-slate-400 font-semibold block">IT SECURITY DEPT: NOTICE</span>
              <p className="text-sm text-slate-700 font-medium">Legacy infrastructure webhooks are migrating. Management tools are restricted to authorized HR Managers only.</p>
            </div>
            <div className="p-3 bg-slate-50 border-l-4 border-slate-400 rounded-r">
              <span className="text-xs text-slate-400 block">HR DEPT: GENERAL</span>
              <p className="text-sm text-slate-600">Q3 performance tracking evaluation window is now open. Update your contact parameters inside settings before Friday.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
