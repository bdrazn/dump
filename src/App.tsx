import { Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Landing from './pages/Landing';
import Analytics from './pages/Analytics';
import Properties from './pages/Properties';
import Contacts from './pages/Contacts';
import Messages from './pages/Messages';
import MessageWheel from './pages/MessageWheel';
import AIChat from './pages/AIChat';
import AIBrain from './pages/AIBrain';
import Activity from './pages/Activity';
import Settings from './pages/Settings';
import Campaigns from './pages/Campaigns';
import Lists from './pages/Lists';
import Tags from './pages/Tags';
import Upload from './pages/Upload';
import Admin from './pages/Admin';
import { useAuth } from './hooks/useAuth';

export default function App() {
  const { session, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-brand-600" />
      </div>
    );
  }

  if (!session) {
    return <Landing />;
  }

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Navigate to="/analytics" replace />} />
        <Route path="analytics" element={<Analytics />} />
        <Route path="properties" element={<Properties />} />
        <Route path="contacts" element={<Contacts />} />
        <Route path="messages" element={<Messages />} />
        <Route path="message-wheel" element={<MessageWheel />} />
        <Route path="ai-chat" element={<AIChat />} />
        <Route path="ai-brain" element={<AIBrain />} />
        <Route path="campaigns" element={<Campaigns />} />
        <Route path="lists" element={<Lists />} />
        <Route path="tags" element={<Tags />} />
        <Route path="upload" element={<Upload />} />
        <Route path="activity" element={<Activity />} />
        <Route path="settings" element={<Settings />} />
        <Route path="admin" element={<Admin />} />
      </Route>
      <Route path="*" element={<Navigate to="/analytics" replace />} />
    </Routes>
  );
}