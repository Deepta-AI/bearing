import { fireEvent, render, screen } from '@testing-library/react-native';

import { ReturnReasonPicker } from './ReturnReasonPicker';

describe('ReturnReasonPicker', () => {
  it('reports the reason the customer taps', () => {
    const onChange = jest.fn();
    render(<ReturnReasonPicker value={null} onChange={onChange} />);
    fireEvent.press(screen.getByRole('radio', { name: 'Wrong item' }));
    expect(onChange).toHaveBeenCalledWith('wrong_item');
  });

  it('marks the chosen reason as checked', () => {
    render(<ReturnReasonPicker value="damaged" onChange={jest.fn()} />);
    expect(screen.getByRole('radio', { name: 'Damaged' })).toBeChecked();
  });
});
