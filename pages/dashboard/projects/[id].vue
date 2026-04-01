<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';
  import { BaseError } from '~/composables/use-error-handler';

  const route = useRoute()
  const projectId = route.params.id as string

  useSeoMeta({
    title: 'Project Details - parsehex Client Portal'
  })

  const supabase = useSupabaseClient<Database>()
  const { errorHandler } = useErrorHandler()

  const user = useSupabaseUser()
  const project = ref<any>(null)
  const updates = ref<any[]>([])
  const isLoading = ref(true)

  const isApproving = ref<string | null>(null)
  const isRejecting = ref<string | null>(null)
  
  const rejectionModal = reactive({
    isOpen: false,
    updateId: '',
    comment: ''
  })

  // Computed for sidebar action items
  const actionItems = computed(() => {
    return updates.value.filter(u => u.requires_approval && u.status === 'pending')
  })

  const fetchProjectDetails = async () => {
    isLoading.value = true

    // Fetch project
    const { data: projectData, error: projectError } = await supabase
        .from('projects')
        .select('*')
        .eq('id', projectId)
        .single()

    if (projectError) {
        errorHandler(new BaseError(projectError.code, projectError.message))
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

  const approveUpdate = async (updateId: string) => {
    try {
        isApproving.value = updateId
        const { error } = await supabase
            .from('project_updates')
            .update({
                status: 'approved',
                approved_at: new Date().toISOString(),
                approved_by: user.value?.id
            })
            .eq('id', updateId)

        if (error) throw error
        await fetchProjectDetails()
    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    } finally {
        isApproving.value = null
    }
  }

  const openRejectionModal = (updateId: string) => {
    rejectionModal.updateId = updateId
    rejectionModal.comment = ''
    rejectionModal.isOpen = true
  }

  const submitRejection = async () => {
    try {
        isRejecting.value = rejectionModal.updateId
        const { error } = await supabase
            .from('project_updates')
            .update({
                status: 'rejected',
                rejection_comment: rejectionModal.comment
            })
            .eq('id', rejectionModal.updateId)

        if (error) throw error
        
        rejectionModal.isOpen = false
        rejectionModal.comment = ''
        await fetchProjectDetails()
    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    } finally {
        isRejecting.value = null
    }
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
                                        <div class="flex items-center gap-2">
                                            <h4 class="text-base font-semibold dark:text-gray-200">{{ update.title }}</h4>
                                            <UBadge v-if="update.requires_approval" :color="update.status === 'pending' ? 'orange' : update.status === 'approved' ? 'emerald' : 'red'" variant="soft" size="xs">
                                                {{ update.status?.toUpperCase() }}
                                            </UBadge>
                                            <UIcon v-if="update.is_blocker" name="i-lucide-octagon-alert" class="w-4 h-4 text-red-500" />
                                        </div>
                                    </div>
                                    <span class="text-xs text-primary font-medium mt-0.5 block">{{ update.created_at ? new Date(update.created_at).toLocaleString() : 'Unknown Date' }}</span>
                                    
                                    <p v-if="update.status === 'rejected' && update.rejection_comment" class="mt-2 text-xs bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-2 rounded">
                                        <strong>Rejection Reason:</strong> {{ update.rejection_comment }}
                                    </p>

                                    <p class="mt-3 text-sm text-gray-600 dark:text-gray-400 whitespace-pre-line">
                                        {{ update.description }}
                                    </p>

                                    <!-- Approval Actions -->
                                    <div v-if="update.requires_approval && update.status === 'pending'" class="mt-4 flex gap-2 border-t border-gray-100 dark:border-gray-800 pt-3">
                                        <UButton size="sm" color="emerald" icon="i-lucide-check" :loading="isApproving === update.id" @click="approveUpdate(update.id)">
                                            Approve
                                        </UButton>
                                        <UButton size="sm" color="red" variant="soft" icon="i-lucide-x" :loading="isRejecting === update.id" @click="openRejectionModal(update.id)">
                                            Reject
                                        </UButton>
                                    </div>
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
                    <div class="flex flex-col gap-3 p-1">
                        <div v-if="actionItems.length === 0" class="flex flex-col items-center justify-center p-4 text-center">
                            <p class="text-sm text-gray-500 italic mb-2">No pending action items for this project.</p>
                            <p class="text-xs text-gray-400">(All caught up!)</p>
                        </div>
                        <div v-else v-for="item in actionItems" :key="item.id" class="p-3 border rounded-lg bg-orange-50 dark:bg-orange-950/20 border-orange-200 dark:border-orange-800 flex items-start gap-3">
                            <UIcon :name="item.is_blocker ? 'i-lucide-octagon-alert' : 'i-lucide-clipboard-check'" class="w-5 h-5 flex-shrink-0" :class="item.is_blocker ? 'text-red-500' : 'text-orange-500'" />
                            <div class="flex-1 overflow-hidden">
                                <p class="text-sm font-bold truncate">{{ item.title }}</p>
                                <p v-if="item.is_blocker" class="text-[10px] text-red-500 font-bold uppercase tracking-wider">Required Blocker</p>
                                <div class="mt-2 flex gap-1">
                                    <UButton size="2xs" color="emerald" @click="approveUpdate(item.id)">Approve</UButton>
                                    <UButton size="2xs" color="gray" variant="ghost" @click="openRejectionModal(item.id)">Reject</UButton>
                                </div>
                            </div>
                        </div>
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

    <!-- Rejection Modal -->
    <UModal v-model="rejectionModal.isOpen">
      <UCard :ui="{ ring: '', divide: 'divide-y divide-gray-100 dark:divide-gray-800' }">
        <template #header>
          <div class="flex items-center justify-between">
            <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
              Reject Update
            </h3>
            <UButton color="gray" variant="ghost" icon="i-lucide-x" class="-my-1" @click="rejectionModal.isOpen = false" />
          </div>
        </template>

        <form @submit.prevent="submitRejection" class="space-y-4">
          <p class="text-sm text-gray-500">Please provide a reason for rejecting this update. This helps us understand what needs to be changed.</p>
          <UFormGroup label="Rejection Reason">
            <UTextarea v-model="rejectionModal.comment" required placeholder="e.g. This color doesn't match our branding..." />
          </UFormGroup>
          
          <div class="pt-4 flex justify-end gap-2">
            <UButton color="gray" variant="soft" @click="rejectionModal.isOpen = false">Cancel</UButton>
            <UButton type="submit" color="red" :loading="isRejecting === rejectionModal.updateId">Submit Rejection</UButton>
          </div>
        </form>
      </UCard>
    </UModal>
  </div>
</template>
