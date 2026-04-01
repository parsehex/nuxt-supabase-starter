<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';

  useSeoMeta({
    title: 'Dashboard - parsehex Client Portal',
  })

  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const { errorHandler } = useErrorHandler()
  
  const projects = ref<Database['public']['Tables']['projects']['Row'][]>([])
  const updates = ref<any[]>([])
  const isLoading = ref(true)

  // Computed for aggregate action items
  const actionItems = computed(() => {
    return updates.value.filter(u => u.requires_approval && u.status === 'pending')
  })

  const fetchData = async () => {
    isLoading.value = true
    try {
        // Fetch projects (RLS handles filtering to their client_id)
        const { data: projData, error: projError } = await supabase
            .from('projects')
            .select('*')
            .order('created_at', { ascending: false })
            
        if (projError) throw projError
        if (projData) projects.value = projData

        // Fetch recent updates (including all pending ones for action items)
        // We'll fetch more than 10 to ensure we catch pending ones, or do a separate query.
        // For simplicity, let's fetch all pending first, then recent 10.
        const { data: pendingData } = await supabase
            .from('project_updates')
            .select('*, projects(name)')
            .eq('requires_approval', true)
            .eq('status', 'pending')

        const { data: recentData, error: updateError } = await supabase
            .from('project_updates')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(10)

        if (updateError) throw updateError
        
        // Combine them for the updates list, ensuring no duplicates
        const combined = [...(pendingData || []), ...(recentData || [])]
        const unique = combined.filter((v, i, a) => a.findIndex(t => t.id === v.id) === i)
        
        updates.value = unique.sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime())

    } catch (e: any) {
        errorHandler(e)
    } finally {
        isLoading.value = false
    }
  }

  onMounted(() => {
    fetchData()
  })
</script>

<template>
  <div class="w-full mx-auto my-10 space-y-8 max-w-7xl px-4 sm:px-6 lg:px-8">
    
    <!-- Header -->
    <div>
      <h1 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-white">
        Dashboard Overview
      </h1>
      <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
        Review your tracked projects and recent developments.
      </p>
    </div>

    <div v-if="isLoading" class="flex justify-center items-center py-20">
        <UIcon name="i-lucide-loader-2" class="w-8 h-8 animate-spin text-gray-500" />
    </div>

    <div v-else class="space-y-8">
      <!-- /* ------------------------------- Action Items ------------------------------ */ -->
      <section v-if="actionItems.length > 0" class="bg-orange-50 dark:bg-orange-950/20 border border-orange-200 dark:border-orange-800 rounded-xl p-6">
        <div class="flex items-center gap-2 mb-4">
          <UIcon name="i-lucide-list-todo" class="w-6 h-6 text-orange-500" />
          <h2 class="text-xl font-bold text-orange-900 dark:text-orange-100">Action Required</h2>
          <UBadge color="orange" variant="solid" size="xs" class="ml-2">{{ actionItems.length }}</UBadge>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <UCard v-for="item in actionItems" :key="item.id" class="border-orange-200 dark:border-orange-800" :ui="{ body: { padding: 'p-4' } }">
            <div class="flex items-start gap-3">
              <UIcon :name="item.is_blocker ? 'i-lucide-octagon-alert' : 'i-lucide-clipboard-check'" class="w-5 h-5 flex-shrink-0" :class="item.is_blocker ? 'text-red-500' : 'text-orange-500'" />
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-[10px] font-bold uppercase tracking-wider text-gray-500">{{ item.projects?.name }}</span>
                  <UBadge v-if="item.is_blocker" color="red" variant="subtle" size="xs">BLOCKER</UBadge>
                </div>
                <p class="text-sm font-bold text-gray-900 dark:text-white truncate">{{ item.title }}</p>
                <div class="mt-3">
                  <UButton size="xs" color="orange" variant="soft" :to="`/dashboard/projects/${item.project_id}`" block>
                    Review & Respond
                  </UButton>
                </div>
              </div>
            </div>
          </UCard>
        </div>
      </section>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      
      <!-- /* ------------------------------- Projects Column ------------------------------ */ -->
      <div class="lg:col-span-2 space-y-6">
        <h2 class="text-xl font-semibold dark:text-gray-200 flex items-center gap-2">
          <UIcon name="i-lucide-folder-kanban" class="w-5 h-5 text-primary" />
          Active Projects
        </h2>

        <div v-if="projects.length === 0" class="p-10 border border-dashed border-gray-300 dark:border-gray-700 rounded-lg text-center">
            <p class="text-gray-500">No projects found. Please contact an administrator to provision a project.</p>
        </div>

        <div v-else class="space-y-4">
          <UCard v-for="project in projects" :key="project.id" class="overflow-hidden">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-bold">{{ project.name }}</h3>
              <UButton size="sm" variant="soft" color="gray" icon="i-lucide-arrow-right" :to="`/dashboard/projects/${project.id}`">View Details</UButton>
            </div>
          </UCard>
        </div>
      </div>

      <!-- /* ------------------------------- Updates Column ------------------------------ */ -->
      <div class="lg:col-span-1 space-y-6">
        <h2 class="text-xl font-semibold dark:text-gray-200 flex items-center gap-2">
          <UIcon name="i-lucide-activity" class="w-5 h-5 text-primary" />
          Recent Updates
        </h2>

        <UCard v-if="updates.length === 0" class="h-full border border-dashed border-gray-300 dark:border-gray-700 text-center">
            <p class="text-gray-500 py-6">No recent updates.</p>
        </UCard>

        <UCard v-else class="h-full">
          <ul class="space-y-6">
            <li v-for="update in updates" :key="update.id" class="relative">
              
              <div class="flex items-start gap-4">
                <div class="flex-shrink-0 mt-1">
                  <UIcon 
                    :name="update.update_type === 'feature' ? 'i-lucide-sparkles' : update.update_type === 'deployment' ? 'i-lucide-rocket' : 'i-lucide-message-square'" 
                    class="w-5 h-5"
                    :class="update.update_type === 'feature' ? 'text-blue-500' : update.update_type === 'deployment' ? 'text-emerald-500' : 'text-gray-400'"
                  />
                </div>
                <div>
                  <div class="flex items-center justify-between gap-4">
                    <h4 class="text-sm font-semibold dark:text-gray-200">{{ update.title }}</h4>
                  </div>
                  <span class="text-xs text-primary font-medium mt-0.5 block">
                    {{ update.created_at ? new Date(update.created_at).toLocaleString() : 'Unknown Date' }}
                  </span>
                  <p class="mt-2 text-sm text-gray-600 dark:text-gray-400 whitespace-pre-line">
                    {{ update.description }}
                  </p>
                </div>
              </div>

            </li>
          </ul>
        </UCard>
      </div>

      </div>
    </div>
  </div>
</template>
