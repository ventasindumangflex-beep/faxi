import React from 'react';
import { router } from 'expo-router';
import { NameForm, useSession } from '@faxi/ui';

export default function Name() {
  const { refresh } = useSession();
  return <NameForm onDone={async () => { await refresh(); router.replace('/'); }} />;
}
