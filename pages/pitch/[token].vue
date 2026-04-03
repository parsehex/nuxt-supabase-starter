<script setup lang="ts">
  import type { Database } from '~/supabase/database.types';

  definePageMeta({
    layout: 'blank' // Assuming a blank layout exists for public pages
  })

  const route = useRoute()
  const supabase = useSupabaseClient<Database>()
  const token = route.params.token as string

  const prospect = ref<any>(null)
  const notes = ref<any[]>([])
  const links = ref<any[]>([])
  const isLoading = ref(true)
  const error = ref<string | null>(null)

  const fetchData = async () => {
    isLoading.value = true
    try {
      // 1. Fetch prospect by share_token
      const { data: pData, error: pError } = await supabase
        .from('clients')
        .select('id, name, contact_email, website')
        .eq('share_token', token)
        .single()

      if (pError || !pData) throw new Error('Invalid or expired pitch link.')
      prospect.value = pData

      // 2. Fetch shared notes and links in parallel
      const [nRes, lRes] = await Promise.all([
        supabase.from('prospect_notes')
          .select('*')
          .eq('client_id', pData.id)
          .eq('is_shareable', true)
          .order('sort_order', { ascending: true })
          .order('created_at', { ascending: true }),
        supabase.from('prospect_links')
          .select('*')
          .eq('client_id', pData.id)
          .eq('is_public', true)
          .order('sort_order', { ascending: true })
      ])

      notes.value = nRes.data || []
      links.value = lRes.data || []

      // 3. Record tracking view (anonymous)
      await supabase.from('pitch_views').insert({
        client_id: pData.id,
        user_agent: navigator.userAgent,
        referrer: document.referrer
      })

    } catch (e: any) {
      error.value = e.message
    } finally {
      isLoading.value = false
    }
  }

  onMounted(() => fetchData())

  useSeoMeta({
    title: () => prospect.value ? `Proposal for ${prospect.value.name} | parsehex` : 'Pitch Proposal | parsehex',
    description: 'A living proposal and vision document for our potential partnership.'
  })
</script>

<template>
  <div class="min-h-screen bg-stone-50 dark:bg-zinc-950 font-sans selection:bg-primary-100 dark:selection:bg-primary-900/30">
    <div v-if="isLoading" class="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <UIcon name="i-lucide-loader-2" class="w-10 h-10 animate-spin text-primary" />
      <p class="text-sm text-gray-500 animate-pulse">Loading your personal pitch...</p>
    </div>

    <div v-else-if="error" class="flex flex-col items-center justify-center min-h-[60vh] px-4 text-center">
      <div class="bg-red-50 dark:bg-red-950/20 p-6 rounded-2xl border border-red-100 dark:border-red-900/40 max-w-md">
        <UIcon name="i-lucide-octagon-alert" class="w-12 h-12 text-red-500 mx-auto mb-4" />
        <h1 class="text-xl font-bold text-red-900 dark:text-red-100 mb-2">Link Unavailable</h1>
        <p class="text-sm text-red-600 dark:text-red-400 mb-6">{{ error }}</p>
        <UButton color="gray" variant="soft" to="/" label="Back to Home" />
      </div>
    </div>

    <div v-else-if="prospect" class="max-w-4xl mx-auto px-6 py-16 md:py-24">
      <!-- Branding & Hero -->
      <header class="mb-20 space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-1000">
        <div class="flex items-center gap-3 opacity-60">
            <div class="w-8 h-8 bg-zinc-900 dark:bg-white rounded-lg flex items-center justify-center">
                <span class="text-white dark:text-zinc-900 font-bold text-lg leading-none">p</span>
            </div>
            <span class="font-bold tracking-tighter text-xl">parsehex</span>
        </div>

        <div class="space-y-4">
          <h1 class="text-4xl md:text-6xl font-extrabold tracking-tight text-zinc-900 dark:text-white leading-[1.1]">
            Vision & Proposal <br/>
            <span class="text-primary-600 dark:text-primary-400 italic">for {{ prospect.name }}</span>
          </h1>
          <p class="text-lg md:text-xl text-zinc-500 dark:text-zinc-400 max-w-2xl leading-relaxed">
            A curated collection of thoughts, resources, and roadmaps for our potential collaboration.
          </p>
        </div>
      </header>

      <!-- Main Content: Curated Notes -->
      <main class="space-y-12 mb-24">
        <section v-if="notes.length > 0" class="space-y-16">
          <div v-for="(note, index) in notes" :key="note.id"
               class="relative pl-8 md:pl-12 group animate-in fade-in slide-in-from-left-4 duration-700"
               :style="{ animationDelay: `${index * 150}ms` }">

            <!-- Timeline connector -->
            <div class="absolute left-0 top-0 bottom-0 w-px bg-zinc-200 dark:bg-zinc-800 group-last:bg-transparent"></div>
            <div class="absolute left-[-4px] top-2 w-2 h-2 rounded-full bg-zinc-400 dark:bg-zinc-600 group-first:bg-primary-500"></div>

            <div class="space-y-4">
              <div class="flex items-center gap-3">
                <UBadge v-if="note.tag" color="gray" variant="soft" size="xs" class="uppercase tracking-widest text-[9px]">{{ note.tag }}</UBadge>
                <span class="text-[10px] text-zinc-400 font-mono">{{ new Date(note.created_at).toLocaleDateString() }}</span>
              </div>

              <div class="prose prose-zinc dark:prose-invert prose-lg max-w-none">
                 <p class="whitespace-pre-line leading-relaxed text-zinc-800 dark:text-zinc-200">
                    {{ note.public_content || note.content }}
                 </p>
              </div>
            </div>
          </div>
        </section>

        <!-- Shared Links -->
        <section v-if="links.length > 0" class="pt-12 border-t border-zinc-200 dark:border-zinc-800 animate-in fade-in duration-1000 delay-500">
           <h2 class="text-sm font-bold uppercase tracking-[0.2em] text-zinc-400 mb-8">Shared Resources</h2>
           <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <a v-for="link in links" :key="link.id" :href="link.url" target="_blank"
                 class="p-6 rounded-2xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 hover:border-primary-400 dark:hover:border-primary-400 transition-all group shadow-sm hover:shadow-xl">
                 <div class="flex justify-between items-start mb-2">
                    <p class="font-bold text-zinc-900 dark:text-zinc-100 group-hover:text-primary-600 transition-colors">{{ link.label || link.url }}</p>
                    <UIcon name="i-lucide-arrow-up-right" class="w-4 h-4 text-zinc-300 group-hover:text-primary-500 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
                 </div>
                 <p v-if="link.description" class="text-sm text-zinc-500 dark:text-zinc-400 leading-relaxed">{{ link.description }}</p>
              </a>
           </div>
        </section>
      </main>

      <!-- Footer CTA -->
      <footer class="bg-zinc-900 dark:bg-zinc-50 rounded-[2.5rem] p-12 md:p-16 text-center space-y-8 animate-in fade-in zoom-in duration-1000 delay-700">
         <div class="space-y-4">
            <h2 class="text-3xl md:text-5xl font-bold text-white dark:text-zinc-900 tracking-tight">Ready to build?</h2>
            <p class="text-zinc-400 dark:text-zinc-500 max-w-md mx-auto">
                If you have questions or want to discuss the next steps, I'm just a message away.
            </p>
         </div>

         <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
            <UButton v-if="prospect.contact_email" size="xl" :to="`mailto:${prospect.contact_email}`" color="white" variant="solid" label="Send a Message" class="px-8 !rounded-full dark:bg-zinc-900 dark:text-white" />
            <UButton size="xl" variant="ghost" color="white" label="Schedule a Call" class="px-8 !rounded-full dark:text-zinc-500" />
         </div>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.prose p {
  margin-top: 0;
  margin-bottom: 1.5em;
}
</style>
