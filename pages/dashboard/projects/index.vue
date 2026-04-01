<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';

  useSeoMeta({
    title: 'Projects - parsehex Client Portal',
  })

  const supabase = useSupabaseClient<Database>()
  const { errorHandler } = useErrorHandler()
  
  const projects = ref<Database['public']['Tables']['projects']['Row'][]>([])
  const isLoading = ref(true)

  const fetchProjects = async () => {
    isLoading.value = true
    try {
        const { data, error } = await supabase
            .from('projects')
            .select('*')
            .order('created_at', { ascending: false })
            
        if (error) throw error
        if (data) projects.value = data

    } catch (e: any) {
        errorHandler(e)
    } finally {
        isLoading.value = false
    }
  }

  onMounted(() => {
    fetchProjects()
  })
</script>

<template>
  <div class="w-full mx-auto my-10 max-w-7xl px-4 sm:px-6 lg:px-8 flex flex-col h-full">
    
    <div class="flex items-center justify-between mb-8">
      <div>
        <h1 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-white">
          Active Projects
        </h1>
        <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
          All projects currently tracked under your organization.
        </p>
      </div>
    </div>

    <div v-if="isLoading" class="flex justify-center items-center py-20">
        <UIcon name="i-lucide-loader-2" class="w-8 h-8 animate-spin text-gray-500" />
    </div>

    <div v-else-if="projects.length === 0" class="p-10 border border-dashed border-gray-300 dark:border-gray-700 rounded-lg text-center flex flex-col items-center">
        <UIcon name="i-lucide-folder-search" class="w-12 h-12 text-gray-400 mb-4" />
        <h3 class="text-lg font-bold mb-2">No Projects Found</h3>
        <p class="text-gray-500">You don't have any active projects currently assigned to you. <br/> Please reach out to your administrator to provision one.</p>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <UCard v-for="project in projects" :key="project.id" class="flex flex-col h-full hover:border-primary transition-colors cursor-pointer" @click="navigateTo(`/dashboard/projects/${project.id}`)">
            <div class="flex items-center justify-between mb-4">
                <UIcon name="i-lucide-folder-kanban" class="w-8 h-8 text-primary" />
                <UBadge color="gray" variant="soft">ID: {{ project.id.split('-')[0] }}</UBadge>
            </div>
            <h3 class="text-lg font-bold mb-2">{{ project.name }}</h3>
            
            <template #footer>
                <div class="flex items-center justify-between mt-auto text-sm text-gray-500">
                    <span>Started: {{ new Date(project.created_at).toLocaleDateString() }}</span>
                    <UButton size="xs" variant="ghost" color="gray" icon="i-lucide-arrow-right">View</UButton>
                </div>
            </template>
        </UCard>
    </div>

  </div>
</template>
