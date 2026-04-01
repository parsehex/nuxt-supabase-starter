<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';

  useSeoMeta({
    title: 'Dashboard - parsehex Client Portal',
  })

  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const { errorHandler } = useErrorHandler()
  
  const projects = ref<Database['public']['Tables']['projects']['Row'][]>([])
  const updates = ref<Database['public']['Tables']['project_updates']['Row'][]>([])
  const isLoading = ref(true)

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

        // Fetch recent updates
        const { data: updateData, error: updateError } = await supabase
            .from('project_updates')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(10)

        if (updateError) throw updateError
        if (updateData) updates.value = updateData

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

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      
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
</template>
