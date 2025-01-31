import { formatDistanceToNow } from 'date-fns';
import { Button } from '@/components/ui/button';
import { Play, Pause, X } from 'lucide-react';
import { formatNumber } from '@/lib/utils';

// Define enum for campaign status to prevent typos and improve maintainability
export enum CampaignStatus {
  RUNNING = 'running',
  SCHEDULED = 'scheduled',
  COMPLETED = 'completed',
  PAUSED = 'paused',
  CANCELLED = 'cancelled'
}

// Separate stats interface for better type organization
interface CampaignStats {
  total_messages: number;
  sent_count: number;
  delivered_count: number;
  response_count: number;
}

interface Campaign {
  id: string;
  name: string;
  status: CampaignStatus;
  scheduled_for: string | null;
  stats: CampaignStats[];
  created_at: string;
}

interface CampaignSummaryProps {
  campaigns: Campaign[];
  onStatusChange: (id: string, status: CampaignStatus) => void;
  onCancel: (id: string) => void;
}

// Separate component for status badge to improve reusability
const StatusBadge = ({ status }: { status: CampaignStatus }) => {
  const statusStyles = {
    [CampaignStatus.RUNNING]: 'bg-green-100 text-green-800',
    [CampaignStatus.SCHEDULED]: 'bg-amber-100 text-amber-800',
    [CampaignStatus.COMPLETED]: 'bg-gray-100 text-gray-800',
    [CampaignStatus.PAUSED]: 'bg-blue-100 text-blue-800',
    [CampaignStatus.CANCELLED]: 'bg-red-100 text-red-800'
  };

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${statusStyles[status]}`}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
};

// Separate component for progress bar to improve reusability
const ProgressBar = ({ progress, sent, total }: { progress: number; sent: number; total: number }) => (
  <div className="space-y-1">
    <div className="flex items-center">
      <div className="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden mr-2">
        <div 
          className="h-full bg-brand-600 rounded-full transition-all duration-300"
          style={{ width: `${Math.min(progress, 100)}%` }}
        />
      </div>
      <span className="text-sm text-gray-500">
        {progress.toFixed(1)}%
      </span>
    </div>
    <div className="text-xs text-gray-500">
      {formatNumber(sent)} / {formatNumber(total)} messages
    </div>
  </div>
);

export function CampaignSummary({ campaigns, onStatusChange, onCancel }: CampaignSummaryProps) {
  const renderActionButtons = (campaign: Campaign) => {
    if (campaign.status === CampaignStatus.COMPLETED || campaign.status === CampaignStatus.CANCELLED) {
      return null;
    }

    return (
      <div className="flex items-center justify-end space-x-2">
        <Button
          size="sm"
          variant="outline"
          onClick={() => onStatusChange(
            campaign.id, 
            campaign.status === CampaignStatus.RUNNING ? CampaignStatus.PAUSED : CampaignStatus.RUNNING
          )}
        >
          {campaign.status === CampaignStatus.RUNNING ? (
            <>
              <Pause className="w-4 h-4 mr-1" />
              Pause
            </>
          ) : (
            <>
              <Play className="w-4 h-4 mr-1" />
              Resume
            </>
          )}
        </Button>
        <Button
          size="sm"
          variant="outline"
          className="text-red-600 hover:text-red-700"
          onClick={() => onCancel(campaign.id)}
        >
          <X className="w-4 h-4 mr-1" />
          Cancel
        </Button>
      </div>
    );
  };

  return (
    <div className="overflow-x-auto rounded-lg border border-gray-200">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            {['Campaign', 'Status', 'Progress', 'Response Rate', 'Started', 'Actions'].map((header) => (
              <th 
                key={header}
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {campaigns.map((campaign) => {
            const stats = campaign.stats[0] ?? {
              total_messages: 0,
              sent_count: 0,
              delivered_count: 0,
              response_count: 0
            };
            
            const progress = stats.total_messages > 0
              ? (stats.sent_count / stats.total_messages) * 100
              : 0;

            const responseRate = stats.delivered_count > 0
              ? (stats.response_count / stats.delivered_count) * 100
              : 0;

            return (
              <tr key={campaign.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm font-medium text-gray-900">{campaign.name}</div>
                  {campaign.scheduled_for && (
                    <div className="text-xs text-gray-500">
                      Scheduled for {new Date(campaign.scheduled_for).toLocaleString()}
                    </div>
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <StatusBadge status={campaign.status} />
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <ProgressBar 
                    progress={progress}
                    sent={stats.sent_count}
                    total={stats.total_messages}
                  />
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm text-gray-900">
                    {responseRate.toFixed(1)}%
                  </div>
                  <div className="text-xs text-gray-500">
                    {formatNumber(stats.response_count)} responses
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDistanceToNow(new Date(campaign.created_at), { addSuffix: true })}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  {renderActionButtons(campaign)}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}