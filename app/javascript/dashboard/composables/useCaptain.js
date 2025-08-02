import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';

export function useCaptain() {
  const store = useStore();
  const { currentAccount } = useAccount();

  const captainEnabled = computed(() => {
    return true;
  });

  const captainLimits = computed(() => {
    return currentAccount.value?.limits?.captain;
  });

  const documentLimits = computed(() => {
    if (captainLimits.value?.documents) {
      return useCamelCase(captainLimits.value.documents);
    }

    return null;
  });

  const responseLimits = computed(() => {
    if (captainLimits.value?.responses) {
      return useCamelCase(captainLimits.value.responses);
    }

    return null;
  });

  const fetchLimits = () => {
    store.dispatch('accounts/limits');
  };

  return {
    captainEnabled,
    captainLimits,
    documentLimits,
    responseLimits,
    fetchLimits,
  };
}
