<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';
  import { BaseError } from '~/composables/use-error-handler';

  definePageMeta({
    layout: 'admin',
    middleware: 'admin'
  })

  useSeoMeta({
    title: 'Admin Dashboard - parsehex Client Portal',
  })

  const supabase = useSupabaseClient<Database>()
  const { errorHandler } = useErrorHandler()

  const pendingApprovals = ref<any[]>([])
  const recentActivity = ref<any[]>([])
  const isLoading = ref(true)

  const fetchData = async () => {
    try {
      isLoading.value = true

      // 1. Fetch all pending client approvals
      const { data: pendingData, error: pendingError } = await supabase
        .from('project_updates')
        .select('*, projects(name, clients(name))')
        .eq('requires_approval', true)
        .eq('status', 'pending')
        .order('created_at', { ascending: false })

      if (pendingError) throw pendingError
      pendingApprovals.value = pendingData || []

      // 2. Fetch recent client activity (Approved/Rejected)
      const { data: activityData, error: activityError } = await supabase
        .from('project_updates')
        .select(`
          *,
          projects(name, clients(name)),
          approved_by_user:users!project_updates_approved_by_fkey(full_name)
        `)
        .eq('requires_approval', true)
        .neq('status', 'pending')
        .order('approved_at', { ascending: false })
        .limit(10)

      if (activityError) throw activityError
      recentActivity.value = activityData || []

    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    } finally {
        isLoading.value = false
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved': return 'emerald'
      case 'rejected': return 'red'
      case 'expired': return 'gray'
      case 'pending': return 'orange'
      default: return 'primary'
    }
  }

  onMounted(() => {
    fetchData()
  })
</script>

<template>
  <div class="h-full flex flex-col pt-5">
    <div class="flex items-center justify-between px-2 py-4">
      <div>
        <h1 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-white">
          Admin Overview
        </h1>
        <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
          Welcome to the System Admin portal. Use the sidebar to manage all clients, users, and projects globally.
        </p>
      </div>
    </div>

    <!-- Live Activity Sections -->
    <div v-if="!isLoading" class="mt-8 space-y-8">

      <!-- 1. Pending Approvals -->
      <section v-if="pendingApprovals.length > 0" class="space-y-4">
        <h2 class="text-xl font-bold flex items-center gap-2">
          <UIcon name="i-lucide-clock" class="w-5 h-5 text-orange-500" />
          Pending Client Sign-offs
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <UCard v-for="item in pendingApprovals" :key="item.id" class="border-orange-100 dark:border-orange-950" :ui="{ body: { padding: 'p-4' } }">
            <div class="flex items-start gap-3">
              <UIcon :name="item.is_blocker ? 'i-lucide-octagon-alert' : 'i-lucide-clipboard-check'" class="w-5 h-5 flex-shrink-0" :class="item.is_blocker ? 'text-red-500' : 'text-orange-500'" />
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500">{{ item.projects?.clients?.name }}</span>
                  <UBadge v-if="item.is_blocker" color="red" variant="subtle" size="xs">BLOCKER</UBadge>
                </div>
                <p class="text-sm font-bold text-gray-900 dark:text-white truncate">{{ item.title }}</p>
                <p class="text-xs text-gray-400 mt-1">Requested {{ new Date(item.created_at).toLocaleString() }}</p>
                <div class="mt-3">
                  <UButton size="xs" color="gray" variant="ghost" icon="i-lucide-arrow-right" :to="`/admin/projects/${item.project_id}`" block>
                    View Project
                  </UButton>
                </div>
              </div>
            </div>
          </UCard>
        </div>
      </section>

      <!-- 2. Recent Activity -->
      <section class="space-y-4">
        <h2 class="text-xl font-bold flex items-center gap-2">
          <UIcon name="i-lucide-activity" class="w-5 h-5 text-primary" />
          Recent Activity
        </h2>

        <UCard v-if="recentActivity.length === 0" class="border border-dashed text-center p-8">
          <p class="text-gray-500 italic">No recent client activity found.</p>
        </UCard>

        <ul v-else class="space-y-3">
          <li v-for="activity in recentActivity" :key="activity.id">
            <UCard class="hover:border-primary-500/50 transition-colors">
              <div class="flex items-center justify-between gap-4">
                <div class="flex items-center gap-4 flex-1">
                  <UIcon
                    :name="activity.status === 'approved' ? 'i-lucide-check-circle' : 'i-lucide-x-circle'"
                    class="w-6 h-6"
                    :class="activity.status === 'approved' ? 'text-emerald-500' : 'text-red-500'"
                  />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium">
                      <span class="font-bold">{{ activity.approved_by_user?.full_name || 'Client' }}</span>
                      <span class="text-gray-500"> {{ activity.status }} </span>
                      <span class="font-bold">"{{ activity.title }}"</span>
                    </p>
                    <p class="text-xs text-gray-400">
                      {{ activity.projects?.clients?.name }} • {{ activity.projects?.name }}
                    </p>
                    <p v-if="activity.status === 'rejected' && activity.rejection_comment" class="mt-2 text-xs text-red-500 italic bg-red-50 dark:bg-red-950 p-2 rounded">
                      "{{ activity.rejection_comment }}"
                    </p>
                  </div>
                </div>
                <div class="text-right flex-shrink-0">
                  <p class="text-xs text-gray-500">{{ new Date(activity.approved_at || activity.created_at).toLocaleString() }}</p>
                  <UButton size="xs" variant="link" color="gray" :to="`/admin/projects/${activity.project_id}`">view project</UButton>
                </div>
              </div>
            </UCard>
          </li>
        </ul>
      </section>

    </div>
  </div>
</template>
