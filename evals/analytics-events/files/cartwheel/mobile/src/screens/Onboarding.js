import React, { useState } from 'react';
import { View, Text, Button } from 'react-native';
import * as analytics from '../analytics';

const STEPS = ['welcome', 'location', 'notifications'];

export default function Onboarding({ onDone }) {
  const [i, setI] = useState(0);
  const step = STEPS[i];

  function next() {
    analytics.track(`onboarding_${step}_completed`, { step_index: i });
    if (i + 1 < STEPS.length) setI(i + 1);
    else onDone();
  }

  return (
    <View>
      <Text>{step}</Text>
      {step === 'welcome' && (
        <Button title="Allow analytics" onPress={() => analytics.setConsent(true)} />
      )}
      <Button title="Next" onPress={next} />
    </View>
  );
}
