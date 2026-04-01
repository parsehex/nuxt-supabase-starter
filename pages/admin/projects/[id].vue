<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';
  import { BaseError } from '~/composables/use-error-handler';

  definePageMeta({
    layout: 'admin',
    middleware: 'admin'
  })

  useSeoMeta({
    title: 'Manage Project - Admin Portal'
  })

  const route = useRoute()
  const projectId = route.params.id as string

  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const { errorHandler } = useErrorHandler()

  const project = ref<any>(null)
  const updates = ref<any[]>([])
  const isLoading = ref(true)

  const isUpdateModalOpen = ref(false)
  const isPosting = ref(false)
  const isReplying = ref<string | null>(null)

  const updateForm = reactive({
    title: '',
    description: '',
    update_type: 'feature',
    requires_approval: false,
    is_blocker: false
  })

  const replyForm = reactive({
    content: ''
  })

  // Table status map
  const statusColors: Record<string, string> = {
    pending: 'orange',
    approved: 'emerald',
    rejected: 'red',
    expired: 'gray',
    follow_up: 'blue'
  }

  const updateTypes = [
    { label: 'Feature', value: 'feature' },
    { label: 'Deployment', value: 'deployment' },
    { label: 'Note', value: 'note' }
  ]

  const fetchProjectDetails = async () => {
    isLoading.value = true
    
    // Fetch project
    const { data: projectData, error: projectError } = await supabase
        .from('projects')
        .select('*, clients(name)')
        .eq('id', projectId)
        .single()
        
    if (projectError) {
        errorHandler(new BaseError(projectError.code, projectError.message))
        return
    }
    
    project.value = projectData

    // Fetch updates with comments
    const { data: updatesData, error: updatesError } = await supabase
        .from('project_updates')
        .select(`
            *,
            comments:update_comments(
                *,
                author:users(full_name)
            )
        `)
        .eq('project_id', projectId)
        .order('created_at', { ascending: false })

    if (updatesData) {
        // Sort comments within each update by date
        updates.value = updatesData.map(u => ({
            ...u,
            comments: (u.comments || []).sort((a: any, b: any) => 
                new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
            )
        }))
    }

    isLoading.value = false
  }

  const postUpdate = async () => {
    try {
        isPosting.value = true

        const { error } = await supabase
            .from('project_updates')
            .insert({
                project_id: projectId,
                title: updateForm.title,
                description: updateForm.description,
                update_type: updateForm.update_type,
                requires_approval: updateForm.requires_approval,
                is_blocker: updateForm.is_blocker,
                status: updateForm.requires_approval ? 'pending' : null,
                author_id: user.value?.id
            })

        if (error) throw error

        updateForm.title = ''
        updateForm.description = ''
        updateForm.update_type = 'feature'
        updateForm.requires_approval = false
        updateForm.is_blocker = false
        isUpdateModalOpen.value = false
        
        await fetchProjectDetails()
    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    } finally {
        isPosting.value = false
    }
  }

  const postReply = async (updateId: string) => {
    if (!replyForm.content.trim() || !user.value?.id) return

    try {
        isReplying.value = updateId
        const { error } = await supabase
            .from('update_comments')
            .insert({
                update_id: updateId as string,
                author_id: user.value.id as string,
                content: replyForm.content
            })

        if (error) throw error
        
        replyForm.content = ''
        await fetchProjectDetails()
    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    } finally {
        isReplying.value = null
    }
  }

  const resolveFollowUp = async (updateId: string) => {
    try {
        const update = updates.value.find(u => u.id === updateId)
        if (!update) return

        // 1. Move current feedback to comments if it exists
        if (update.client_feedback) {
            const { error: commentError } = await supabase
                .from('update_comments')
                .insert({
                    update_id: updateId,
                    author_id: user.value?.id as string,
                    content: `[Previous Feedback]: ${update.client_feedback}`
                })
            
            if (commentError) throw commentError
        }

        // 2. Reset status and clear feedback
        const { error: updateError } = await supabase
            .from('project_updates')
            .update({ 
                status: 'pending',
                client_feedback: null 
            })
            .eq('id', updateId)

        if (updateError) throw updateError
        
        await fetchProjectDetails()
    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    }
  }

  const deleteUpdate = async (id: string) => {
    if (!confirm('Are you sure you want to delete this update?')) return
    
    try {
        const { error } = await supabase
            .from('project_updates')
            .delete()
            .eq('id', id)
            
        if (error) throw error
        await fetchProjectDetails()
    } catch (e: any) {
        errorHandler(new BaseError(e.code, e.message))
    }
  }

  onMounted(() => {
    fetchProjectDetails()
  })
</script>

<template>
  <div class="h-full flex flex-col pt-5">
    <div class="mb-4 px-2">
        <UButton variant="ghost" color="gray" icon="i-lucide-arrow-left" to="/admin/projects" size="sm">Back to Projects</UButton>
    </div>

    <div v-if="isLoading" class="flex justify-center p-10">
        <UIcon name="i-lucide-loader-2" class="w-8 h-8 animate-spin text-gray-500" />
    </div>

    <div v-else-if="project" class="flex-1">
        <div class="flex items-center justify-between px-2 py-4 border-b border-gray-200 dark:border-gray-800 mb-6">
            <div>
                <h1 class="text-3xl font-bold">{{ project.name }}</h1>
                <p class="text-gray-500 flex items-center gap-2 mt-1">
                    <UIcon name="i-lucide-building-2" class="w-4 h-4"/>
                    {{ project.clients?.name }}
                </p>
            </div>
            <UButton icon="i-lucide-megaphone" label="Post Update" @click="isUpdateModalOpen = true" />
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 px-2">
            <!-- Details Column -->
            <div class="col-span-1 space-y-6">
                <UCard>
                    <template #header>
                        <h3 class="font-bold">Project Info</h3>
                    </template>
                    <div class="space-y-4 text-sm">
                        <div>
                            <span class="text-gray-500 block mb-1">Project ID</span>
                            <span class="font-mono bg-gray-100 dark:bg-gray-800 p-1 rounded">{{ project.id }}</span>
                        </div>
                        <div>
                            <span class="text-gray-500 block mb-1">Created At</span>
                            <span>{{ new Date(project.created_at).toLocaleString() }}</span>
                        </div>
                    </div>
                </UCard>
            </div>

            <!-- Updates Feed Column -->
            <div class="col-span-2">
                <h2 class="text-xl font-semibold mb-4 flex items-center gap-2">
                    <UIcon name="i-lucide-activity" class="w-5 h-5 text-primary" />
                    Latest Updates
                </h2>

                <div v-if="updates.length === 0" class="text-center p-10 border border-dashed border-gray-300 dark:border-gray-700 rounded-lg">
                    <p class="text-gray-500">No updates posted yet.</p>
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
                                            <UBadge v-if="update.requires_approval" :color="statusColors[update.status as keyof typeof statusColors]" variant="soft" size="xs">
                                                {{ update.status?.toUpperCase() }}
                                            </UBadge>
                                            <UIcon v-if="update.is_blocker" name="i-lucide-octagon-alert" class="w-4 h-4 text-red-500" />
                                        </div>
                                        <UButton color="red" variant="ghost" size="xs" icon="i-lucide-trash" class="opacity-0 group-hover:opacity-100 transition-opacity" @click="deleteUpdate(update.id)" />
                                    </div>
                                    <span class="text-xs text-primary font-medium mt-0.5 block">{{ update.created_at ? new Date(update.created_at).toLocaleString() : 'Unknown Date' }}</span>
                                    
                                    <!-- Official Record Box (The status note) -->
                                    <div v-if="update.client_feedback" class="mt-3 p-3 rounded-lg border text-sm" :class="update.status === 'rejected' ? 'bg-red-50 dark:bg-red-950/20 border-red-100 dark:border-red-900 text-red-700 dark:text-red-400' : update.status === 'approved' ? 'bg-emerald-50 dark:bg-emerald-950/20 border-emerald-100 dark:border-emerald-900 text-emerald-700 dark:text-emerald-400' : 'bg-blue-50 dark:bg-blue-950/20 border-blue-100 dark:border-blue-900 text-blue-700 dark:text-blue-400'">
                                        <div class="flex items-center gap-2 mb-1">
                                            <UIcon :name="update.status === 'approved' ? 'i-lucide-check-circle' : update.status === 'rejected' ? 'i-lucide-x-circle' : 'i-lucide-help-circle'" class="w-4 h-4" />
                                            <span class="font-bold uppercase tracking-wider text-[10px]">Official client feedback</span>
                                        </div>
                                        <p>{{ update.client_feedback }}</p>
                                    </div>

                                    <p class="mt-3 text-sm text-gray-600 dark:text-gray-400 whitespace-pre-line border-b border-gray-100 dark:border-gray-800 pb-4">
                                        {{ update.description }}
                                    </p>

                                    <!-- Conversation Thread -->
                                    <div class="mt-4 space-y-4">
                                        <div v-if="update.comments && update.comments.length > 0" class="space-y-3">
                                            <div v-for="comment in update.comments" :key="comment.id" class="flex gap-3 text-xs">
                                                <div class="flex-1 bg-gray-50 dark:bg-gray-900/50 p-2 rounded border border-gray-100 dark:border-gray-800">
                                                    <div class="flex items-center justify-between mb-1">
                                                        <span class="font-bold text-gray-700 dark:text-gray-300">{{ comment.author?.full_name || 'System' }}</span>
                                                        <span class="text-[10px] text-gray-400">{{ new Date(comment.created_at).toLocaleString() }}</span>
                                                    </div>
                                                    <p class="dark:text-gray-400 whitespace-pre-wrap">{{ comment.content }}</p>
                                                </div>
                                            </div>
                                        </div>

                                        <!-- Reply Area -->
                                        <div class="flex flex-col gap-2 pt-2">
                                            <div v-if="update.status === 'follow_up'" class="flex items-center gap-2 mb-2 p-2 bg-blue-50 dark:bg-blue-900/20 rounded border border-blue-100 dark:border-blue-800">
                                                <UIcon name="i-lucide-help-circle" class="w-4 h-4 text-blue-500" />
                                                <span class="text-xs font-medium text-blue-700 dark:text-blue-300 flex-1">Client requested a follow-up. Respond below.</span>
                                                <UButton size="2xs" color="blue" variant="solid" @click="resolveFollowUp(update.id)">Resolve & Resubmit</UButton>
                                            </div>

                                            <div class="flex gap-2">
                                                <UInput 
                                                    v-model="replyForm.content" 
                                                    placeholder="Write a reply..." 
                                                    size="xs" 
                                                    class="flex-1"
                                                    :disabled="isReplying !== null && isReplying !== update.id"
                                                    @keyup.enter="postReply(update.id)"
                                                />
                                                <UButton 
                                                    size="xs" 
                                                    color="primary" 
                                                    icon="i-lucide-send" 
                                                    :loading="isReplying === update.id" 
                                                    @click="postReply(update.id)"
                                                >
                                                    Reply
                                                </UButton>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </UCard>
                    </li>
                </ul>
            </div>
        </div>
    </div>

    <!-- Create Update Modal -->
    <UModal v-model="isUpdateModalOpen">
      <UCard :ui="{ ring: '', divide: 'divide-y divide-gray-100 dark:divide-gray-800' }">
        <template #header>
          <div class="flex items-center justify-between">
            <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
              Post Project Update
            </h3>
            <UButton color="gray" variant="ghost" icon="i-lucide-x" class="-my-1" @click="isUpdateModalOpen = false" />
          </div>
        </template>

        <form @submit.prevent="postUpdate" class="space-y-4">
          <UFormGroup label="Title">
            <UInput v-model="updateForm.title" required placeholder="e.g. Deployed Staging Environment" />
          </UFormGroup>
          
          <UFormGroup label="Update Type">
            <USelect 
                v-model="updateForm.update_type"
                required
                :options="updateTypes"
            />
          </UFormGroup>

          <UFormGroup label="Description (Optional)">
            <UTextarea v-model="updateForm.description" :rows="4" placeholder="Add some context or patch notes..." />
          </UFormGroup>

          <UDivider label="Approvals" />

          <div class="space-y-2">
            <UCheckbox v-model="updateForm.requires_approval" label="Requires Client Approval" />
            <UCheckbox v-if="updateForm.requires_approval" v-model="updateForm.is_blocker" label="Mark as Blocker" color="red" />
          </div>
          
          <div class="pt-4 flex justify-end gap-2">
            <UButton color="gray" variant="soft" @click="isUpdateModalOpen = false">Cancel</UButton>
            <UButton type="submit" :loading="isPosting">Post Update</UButton>
          </div>
        </form>
      </UCard>
    </UModal>
  </div>
</template>
