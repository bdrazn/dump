import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
import { MessageSquare, CheckCircle2, Clock, BarChart2 } from 'lucide-react';
import { Progress } from '../ui/progress';

interface MessageKPIProps {
  stats: {
    sent: number;
    delivered: number;
    responses: number;
    responseRate: number;
  };
}

export function MessageKPI({ stats }: MessageKPIProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-lg font-medium">Message Performance</CardTitle>
        <BarChart2 className="h-5 w-5 text-gray-500" />
      </CardHeader>
      <CardContent>
        <div className="space-y-6">
          {/* Sent Messages */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center">
                <MessageSquare className="w-4 h-4 text-gray-400 mr-2" />
                <span className="text-sm font-medium text-gray-700">Messages Sent</span>
              </div>
              <span className="text-sm font-medium">{stats.sent}</span>
            </div>
            <Progress value={100} className="bg-blue-100">
              <div className="bg-blue-500" style={{ width: '100%' }} />
            </Progress>
          </div>

          {/* Delivered Messages */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center">
                <CheckCircle2 className="w-4 h-4 text-gray-400 mr-2" />
                <span className="text-sm font-medium text-gray-700">Delivered</span>
              </div>
              <span className="text-sm font-medium">{stats.delivered}</span>
            </div>
            <Progress value={(stats.delivered / stats.sent) * 100} className="bg-green-100">
              <div className="bg-green-500" />
            </Progress>
          </div>

          {/* Response Rate */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center">
                <Clock className="w-4 h-4 text-gray-400 mr-2" />
                <span className="text-sm font-medium text-gray-700">Response Rate</span>
              </div>
              <span className="text-sm font-medium">{stats.responseRate}%</span>
            </div>
            <Progress value={stats.responseRate} className="bg-amber-100">
              <div className="bg-amber-500" />
            </Progress>
          </div>

          {/* Additional Stats */}
          <div className="grid grid-cols-2 gap-4 pt-4 border-t">
            <div>
              <div className="text-sm font-medium text-gray-500">Total Responses</div>
              <div className="mt-1 text-2xl font-semibold">{stats.responses}</div>
            </div>
            <div>
              <div className="text-sm font-medium text-gray-500">Delivery Rate</div>
              <div className="mt-1 text-2xl font-semibold">
                {((stats.delivered / stats.sent) * 100).toFixed(1)}%
              </div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}