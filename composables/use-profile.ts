import type { Database } from '~/supabase/database.types';

export const useProfile = () => {
    const supabase = useSupabaseClient<Database>()
    const auth = useSupabaseUser()
    const isSystemAdmin = ref(false)
    const profileData = ref<Database['public']['Tables']['users']['Row'] | null>(null)
    const isLoading = ref(true)

    const fetchProfile = async () => {
        if (!auth.value?.id) {
            isLoading.value = false
            return
        }

        isLoading.value = true
        const { data, error } = await supabase
            .from('users')
            .select('*')
            .eq('id', auth.value.id)
            .single()

        if (data) {
            profileData.value = data
            isSystemAdmin.value = data.is_system_admin || false
        }
        
        isLoading.value = false
    }

    onMounted(() => {
        fetchProfile()
    })

    return {
        profile: profileData,
        isSystemAdmin,
        isLoading,
        refresh: fetchProfile
    }
}
