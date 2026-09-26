import { fireEvent, render, screen } from '@testing-library/react-native';

import { ApiError } from '@/lib/api';

import { HealthCard } from './components/HealthCard';

describe('HealthCard', () => {
  it('shows the loading state', () => {
    render(<HealthCard status="pending" data={undefined} error={null} onRetry={() => {}} />);
    expect(screen.getByText('Checking the API')).toBeOnTheScreen();
    expect(screen.getByLabelText('Loading')).toBeOnTheScreen();
  });

  it('maps an ApiError to copy and retries on press', () => {
    const onRetry = jest.fn();
    render(
      <HealthCard
        status="error"
        data={undefined}
        error={new ApiError(503, null)}
        onRetry={onRetry}
      />,
    );
    expect(screen.getByText('The API answered 503.')).toBeOnTheScreen();
    fireEvent.press(screen.getByRole('button', { name: 'Retry health check' }));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });

  it('shows the empty state when the query settled with no data', () => {
    render(<HealthCard status="success" data={undefined} error={null} onRetry={() => {}} />);
    expect(screen.getByText('No health data yet.')).toBeOnTheScreen();
  });

  it('shows status and version when the API answered', () => {
    render(
      <HealthCard
        status="success"
        data={{ status: 'ok', version: '1.2.3' }}
        error={null}
        onRetry={() => {}}
      />,
    );
    expect(screen.getByText('API ok (v1.2.3)')).toBeOnTheScreen();
  });
});
