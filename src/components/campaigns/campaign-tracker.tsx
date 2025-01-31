import { Card } from '../ui/card';
import { Progress } from '../ui/progress';
import { Clock, MessageSquare, Building2, AlertCircle } from 'lucide-react';
import { formatNumber } from '@/lib/utils';

interface CampaignTrackerProps {
  campaign: {
    id: string;
    name: string;
    status: string;
    scheduled_for: string | null;
    stats: {
      total_messages: number;
      sent_count: number;
      delivered_count: number;
      failed_count: number;
      response_count: number;
    }[];
    target_list: {
      property_count?: number;
    };
  };
  dailyLimit: number;
}

export function CampaignTracker({ campaign, dailyLimit }: CampaignTrackerProps) {
  // Calculate progress percentages
  const totalProperties = campaign.target_list.property_count || 0;
  const totalMessages = campaign.stats?.[0]?.total_messages || 0;
  const sentMessages = campaign.stats?.[0]?.sent_count || 0;
  const deliveredMessages = campaign.stats?.[0]?.delivered_count || 0;
  const failedMessages = campaign.stats?.[0]?.failed_count || 0;
  const responseCount = campaign.stats?.[0]?.response_count || 0;

  const propertiesProgress = totalProperties > 0 
    ? (sentMessages / totalProperties) * 100 
    : 0;

  const deliveryRate = sentMessages > 0 
    ? (deliveredMessages / sentMessages) * 100 
    : 0;

  const responseRate = deliveredMessages > 0 
    ? (responseCount / deliveredMessages) * 100 
    : 0;

  // Calculate estimated days remaining based on daily limit
  const remainingMessages = totalMessages - sentMessages;
  const estimatedDays = Math.ceil(remainingMessages / dailyLimit);

  return (
    <div className="space-y-6">
      {/* Overall Progress */}
      <Card className="p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-medium">Campaign Progress</h3>
          <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${
            campaign.status === 'running'
              ? 'bg-green-100 text-green-800'
              : campaign.status === 'scheduled'
              ? 'bg-amber-100 text-amber-800'
              : campaign.status === 'completed'
              ? 'bg-gray-100 text-gray-800'
              : 'bg-red-100 text-red-800'
          }`}>
            {campaign.status.charAt(0).toUpperCase() + campaign.status.slice(1)}
          </span>
        </div>

        <div className="space-y-4">
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-sm font-medium text-gray-700">Properties Reached</span>
              <span className="text-sm text-gray-500">
                {formatNumber(sentMessages)} / {formatNumber(totalProperties)}
              </span>
            </div>
            <Progress value={propertiesProgress} className="h-2">
              <div className="bg-brand-600" style={{ width: `${propertiesProgress}%` }} />
            </Progress>
          </div>

          <div>
            <div className="flex justify-between mb-2">
              <span className="text-sm font-medium text-gray-700">Message Delivery Rate</span>
              <span className="text-sm text-gray-500">
                {deliveryRate.toFixed(1)}%
              </span>
            </div>
            <Progress value={deliveryRate} className="h-2">
              <div className="bg-blue-600" style={{ width: `${deliveryRate}%` }} />
            </Progress>
          </div>

          <div>
            <div className="flex justify-between mb-2">
              <span className="text-sm font-medium text-gray-700">Response Rate</span>
              <span className="text-sm text-gray-500">
                {responseRate.toFixed(1)}%
              </span>
            </div>
            <Progress value={responseRate} className="h-2">
              <div className="bg-purple-600" style={{ width: `${responseRate}%` }} />
            </Progress>
          </div>
        </div>
      </Card>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Messages Sent</p>
              <p className="text-2xl font-semibold mt-1">{formatNumber(sentMessages)}</p>
            </div>
            <MessageSquare className="h-8 w-8 text-brand-600" />
          </div>
          <p className="mt-2 text-sm text-gray-500">
            {formatNumber(totalMessages - sentMessages)} remaining
          </p>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Properties</p>
              <p className="text-2xl font-semibold mt-1">{formatNumber(totalProperties)}</p>
            </div>
            <Building2 className="h-8 w-8 text-blue-600" />
          </div>
          <p className="mt-2 text-sm text-gray-500">
            {formatNumber(totalProperties - sentMessages)} not contacted
          </p>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Est. Days Left</p>
              <p className="text-2xl font-semibold mt-1">{estimatedDays}</p>
            </div>
            <Clock className="h-8 w-8 text-purple-600" />
          </div>
          <p className="mt-2 text-sm text-gray-500">
            Based on {formatNumber(dailyLimit)} daily limit
          </p>
        </Card>

        <Card className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Failed Messages</p>
              <p className="text-2xl font-semibold mt-1">{formatNumber(failedMessages)}</p>
            </div>
            <AlertCircle className="h-8 w-8 text-red-600" />
          </div>
          <p className="mt-2 text-sm text-gray-500">
            {((failedMessages / sentMessages) * 100).toFixed(1)}% failure rate
          </p>
        </Card>
      </div>
    </div>
  );
}