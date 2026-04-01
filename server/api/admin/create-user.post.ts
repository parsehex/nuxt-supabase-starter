import { serverSupabaseServiceRole, serverSupabaseUser } from '#supabase/server'
import type { Database } from '~/supabase/database.types'

export default defineEventHandler(async (event) => {
    // 1. Verify the requester is a system admin
    const supabase = await serverSupabaseServiceRole<Database>(event)
    const currentUser = await serverSupabaseUser(event)

    if (!currentUser) {
        throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
    }

    // Check if current user is a system admin in the public.users table
    const { data: adminCheck } = await supabase
        .from('users')
        .select('is_system_admin')
        .eq('id', currentUser.id)
        .single()

    if (!adminCheck?.is_system_admin) {
        throw createError({ statusCode: 403, statusMessage: 'Forbidden: Requires System Admin privileges' })
    }

    // 2. Parse body
    const body = await readBody(event)
    const { email, password, full_name, role, client_id } = body

    if (!email || !password) {
        throw createError({ statusCode: 400, statusMessage: 'Email and password are required' })
    }

    // 3. Create user using admin API
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
            full_name: full_name || null
        }
    })

    if (authError) {
        throw createError({ statusCode: 400, statusMessage: authError.message })
    }

    // Since we have a trigger that automatically creates the public.users record
    // we just need to update it with the additional metadata if provided.
    
    if (client_id || role || full_name) {
        const updateData: any = {}
        if (client_id) updateData.client_id = client_id
        if (role) updateData.role = role
        if (full_name) updateData.full_name = full_name

        const { error: updateError } = await supabase
            .from('users')
            .update(updateData)
            .eq('id', authData.user.id)

        if (updateError) {
            // Log it but don't fail the whole request since the user was created
            console.error('Failed to update user profile metadata:', updateError)
        }
    }

    return {
        success: true,
        user: authData.user
    }
})
