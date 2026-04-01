<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';

  const route = useRoute()
  const projectId = route.params.id as string

  useSeoMeta({
    title: 'Project Details - parsehex Client Portal'
  })

  const supabase = useSupabaseClient<Database>()
  const { errorHandler } = useErrorHandler()

  const project = ref<any>(null)
  const updates = ref<Database['public']['Tables']['project_updates']['Row'][]>([])
  const isLoading = ref(true)

  const fetchProjectDetails = async () => {
    isLoading.value = true

    // Fetch project
    const { data: projectData, error: projectError } = await supabase
        .from('projects')
        .select('*')
        .eq('id', projectId)
        .single()

    if (projectError) {
        errorHandler(projectError)
        return
    }

    project.value = projectData

    // Fetch updates
    const { data: updatesData } = await supabase
        .from('project_updates')
        .select('*')
        .eq('project_id', projectId)
        .order('created_at', { ascending: false })

    if (updatesData) {
        updates.value = updatesData
    }

    isLoading.value = false
  }

  onMounted(() => {
    fetchProjectDetails()
  })
</script>

<template>
  <div class="w-full mx-auto my-10 max-w-7xl px-4 sm:px-6 lg:px-8 flex flex-col h-full">

    <div class="mb-4">
        <UButton variant="ghost" color="gray" icon="i-lucide-arrow-left" to="/dashboard/projects" size="sm">Back to Projects</UButton>
    </div>

    <div v-if="isLoading" class="flex justify-center p-10">
        <UIcon name="i-lucide-loader-2" class="w-8 h-8 animate-spin text-gray-500" />
    </div>

    <div v-else-if="project" class="flex-1">

        <div class="flex items-center justify-between py-4 border-b border-gray-200 dark:border-gray-800 mb-6">
            <div>
                <h1 class="text-3xl font-bold">{{ project.name }}</h1>
            </div>
            <UBadge color="gray" variant="soft">ID: {{ project.id.split('-')[0] }}</UBadge>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Updates Feed Column -->
            <div class="lg:col-span-2">
                <h2 class="text-xl font-semibold mb-6 flex items-center gap-2">
                    <UIcon name="i-lucide-activity" class="w-5 h-5 text-primary" />
                    Project Updates
                </h2>

                <div v-if="updates.length === 0" class="text-center p-10 border border-dashed border-gray-300 dark:border-gray-700 rounded-lg">
                    <p class="text-gray-500">No updates have been posted for this project yet.</p>
                </div>

                <ul v-else class="space-y-6">
                    <li v-for="update in updates" :key="update.id" class="relative group">
                        <UCard>
                            <div class="flex items-start gap-4">
                                <div class="flex-shrink-0 mt-1">
                                    <UIcon
                                        :name="update.update_type === 'feature' ? 'i-lucide-sparkles' : update.update_type === 'deployment' ? 'i-lucide-rocket' : 'i-lucide-message-square'"
                                        class="w-5 h-5"
                                        :class="update.update_type === 'feature' ? 'text-blue-500' : update.update_type === 'deployment' ? 'text-emerald-500' : 'text-gray-400'"
                                    />
                                </div>
                                <div class="flex-1">
                                    <div class="flex items-center justify-between gap-4">
                                        <h4 class="text-base font-semibold dark:text-gray-200">{{ update.title }}</h4>
                                    </div>
                                    <span class="text-xs text-primary font-medium mt-0.5 block">{{ new Date(update.created_at).toLocaleString() }}</span>
                                    <p class="mt-3 text-sm text-gray-600 dark:text-gray-400 whitespace-pre-line">
                                        {{ update.description }}
                                    </p>
                                </div>
                            </div>
                        </UCard>
                    </li>
                </ul>
            </div>

            <!-- Sidebar / Action Items Placeholder -->
            <div class="lg:col-span-1 space-y-6">
                <!-- Action Items Placeholder -->
                <UCard class="w-full">
                    <template #header>
                        <h2 class="text-lg font-semibold flex items-center gap-2">
                            <UIcon name="i-lucide-list-todo" class="w-5 h-5 text-emerald-500" />
                            Action Items
                        </h2>
                    </template>
                    <div class="flex flex-col items-center justify-center p-4 text-center">
                        <p class="text-sm text-gray-500 italic mb-2">No pending action items for this project.</p>
                        <p class="text-xs text-gray-400">(This section is reserved for future features like document signing or approvals)</p>
                    </div>
                </UCard>

                <!-- Documents / Files Placeholder (Hidden for now) -->
                <UCard class="w-full hidden">
                    <template #header>
                        <div class="flex items-center justify-between">
                            <h2 class="text-lg font-semibold flex items-center gap-2">
                                <UIcon name="i-lucide-file-text" class="w-5 h-5 text-primary" />
                                Recent Files
                            </h2>
                            <UButton size="2xs" variant="ghost" color="gray" to="/dashboard/files">View All</UButton>
                        </div>
                    </template>
                    <div class="flex flex-col items-center justify-center p-2 text-center">
                        <p class="text-sm text-gray-500 italic">No files attached to this project.</p>
                    </div>
                </UCard>
            </div>
        </div>
    </div>
  </div>
</template>
