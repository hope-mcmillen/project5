export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {

  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "app_config": {
                  Row: {
                    "daily_apply_cap": number,"id": boolean,"reject_undo_seconds": number,"scoring_version": string,"undo_seconds": number
                  }
                  ComputedFields: never
                  Insert: {
                    "daily_apply_cap"?: number,"id"?: boolean,"reject_undo_seconds"?: number,"scoring_version"?: string,"undo_seconds"?: number
                  }
                  Update: {
                    "daily_apply_cap"?: number,"id"?: boolean,"reject_undo_seconds"?: number,"scoring_version"?: string,"undo_seconds"?: number
                  }
                  Relationships: [

                  ]
                },"application_reject_reasons": {
                  Row: {
                    "application_id": string,"created_at": string,"created_by": string | null,"reason": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "application_id": string,"created_at"?: string,"created_by"?: string | null,"reason"?: string | null
                  }
                  Update: {
                    "application_id"?: string,"created_at"?: string,"created_by"?: string | null,"reason"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "application_reject_reasons_application_id_fkey"
      columns: ["application_id"]
isOneToOne: true
      referencedRelation: "applications"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "application_reject_reasons_application_id_fkey"
      columns: ["application_id"]
isOneToOne: true
      referencedRelation: "my_applications"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "application_reject_reasons_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"applications": {
                  Row: {
                    "advanced_by": string | null,"anonymized": boolean,"breakdown": NonNullable<Json>,"candidate_id": string | null,"committed_at": string,"created_at": string,"id": string,"interview_note": string | null,"is_seed": boolean,"job_id": string,"match_score": number,"previous_status": Database["public"]['Enums']["application_status"] | null,"profile_version_id": string | null,"rejected_at": string | null,"scoring_version": string,"status": Database["public"]['Enums']["application_status"],"swipe_id": string | null,"updated_at": string,"application_tile": Json | null
                  }
                  ComputedFields: "application_tile"
                  Insert: {
                    "advanced_by"?: string | null,"anonymized"?: boolean,"breakdown"?: NonNullable<Json>,"candidate_id"?: string | null,"committed_at": string,"created_at"?: string,"id"?: string,"interview_note"?: string | null,"is_seed"?: boolean,"job_id": string,"match_score": number,"previous_status"?: Database["public"]['Enums']["application_status"] | null,"profile_version_id"?: string | null,"rejected_at"?: string | null,"scoring_version": string,"status"?: Database["public"]['Enums']["application_status"],"swipe_id"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "advanced_by"?: string | null,"anonymized"?: boolean,"breakdown"?: NonNullable<Json>,"candidate_id"?: string | null,"committed_at"?: string,"created_at"?: string,"id"?: string,"interview_note"?: string | null,"is_seed"?: boolean,"job_id"?: string,"match_score"?: number,"previous_status"?: Database["public"]['Enums']["application_status"] | null,"profile_version_id"?: string | null,"rejected_at"?: string | null,"scoring_version"?: string,"status"?: Database["public"]['Enums']["application_status"],"swipe_id"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "applications_advanced_by_fkey"
      columns: ["advanced_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "applications_candidate_id_fkey"
      columns: ["candidate_id"]
isOneToOne: false
      referencedRelation: "candidates"
      referencedColumns: ["profile_id"]
    },{
      foreignKeyName: "applications_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "company_jobs_overview"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "applications_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "applications_profile_version_id_fkey"
      columns: ["profile_version_id"]
isOneToOne: false
      referencedRelation: "profile_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "applications_swipe_id_fkey"
      columns: ["swipe_id"]
isOneToOne: true
      referencedRelation: "swipes"
      referencedColumns: ["id"]
    }
                  ]
                },"candidate_experiences": {
                  Row: {
                    "end_month": string | null,"evidence": string,"highlights": (string)[],"id": string,"kind": Database["public"]['Enums']["experience_kind"],"organization": string | null,"profile_version_id": string,"skills_used": (string)[],"sort_order": number,"start_month": string | null,"title": string
                  }
                  ComputedFields: never
                  Insert: {
                    "end_month"?: string | null,"evidence": string,"highlights"?: (string)[],"id"?: string,"kind"?: Database["public"]['Enums']["experience_kind"],"organization"?: string | null,"profile_version_id": string,"skills_used"?: (string)[],"sort_order": number,"start_month"?: string | null,"title": string
                  }
                  Update: {
                    "end_month"?: string | null,"evidence"?: string,"highlights"?: (string)[],"id"?: string,"kind"?: Database["public"]['Enums']["experience_kind"],"organization"?: string | null,"profile_version_id"?: string,"skills_used"?: (string)[],"sort_order"?: number,"start_month"?: string | null,"title"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "candidate_experiences_profile_version_id_fkey"
      columns: ["profile_version_id"]
isOneToOne: false
      referencedRelation: "profile_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"candidate_skills": {
                  Row: {
                    "evidence": string | null,"id": string,"profile_version_id": string,"raw_name": string,"skill_id": string | null,"source": Database["public"]['Enums']["skill_source"],"years": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "evidence"?: string | null,"id"?: string,"profile_version_id": string,"raw_name": string,"skill_id"?: string | null,"source"?: Database["public"]['Enums']["skill_source"],"years"?: number | null
                  }
                  Update: {
                    "evidence"?: string | null,"id"?: string,"profile_version_id"?: string,"raw_name"?: string,"skill_id"?: string | null,"source"?: Database["public"]['Enums']["skill_source"],"years"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "candidate_skills_profile_version_id_fkey"
      columns: ["profile_version_id"]
isOneToOne: false
      referencedRelation: "profile_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "candidate_skills_skill_id_fkey"
      columns: ["skill_id"]
isOneToOne: false
      referencedRelation: "skills"
      referencedColumns: ["id"]
    }
                  ]
                },"candidates": {
                  Row: {
                    "active_version_id": string | null,"created_at": string,"discoverable": boolean,"is_seed": boolean,"preferences": NonNullable<Json>,"profile_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "active_version_id"?: string | null,"created_at"?: string,"discoverable"?: boolean,"is_seed"?: boolean,"preferences"?: NonNullable<Json>,"profile_id": string,"updated_at"?: string
                  }
                  Update: {
                    "active_version_id"?: string | null,"created_at"?: string,"discoverable"?: boolean,"is_seed"?: boolean,"preferences"?: NonNullable<Json>,"profile_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "candidates_active_version_fk"
      columns: ["active_version_id"]
isOneToOne: false
      referencedRelation: "profile_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "candidates_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"companies": {
                  Row: {
                    "created_at": string,"created_by": string | null,"id": string,"is_seed": boolean,"logo_path": string | null,"name": string,"updated_at": string,"verified": boolean,"website": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"created_by"?: string | null,"id"?: string,"is_seed"?: boolean,"logo_path"?: string | null,"name": string,"updated_at"?: string,"verified"?: boolean,"website"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string | null,"id"?: string,"is_seed"?: boolean,"logo_path"?: string | null,"name"?: string,"updated_at"?: string,"verified"?: boolean,"website"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "companies_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"company_invites": {
                  Row: {
                    "code": string,"company_id": string,"created_at": string,"created_by": string | null,"expires_at": string,"max_uses": number,"revoked_at": string | null,"uses": number
                  }
                  ComputedFields: never
                  Insert: {
                    "code": string,"company_id": string,"created_at"?: string,"created_by"?: string | null,"expires_at": string,"max_uses"?: number,"revoked_at"?: string | null,"uses"?: number
                  }
                  Update: {
                    "code"?: string,"company_id"?: string,"created_at"?: string,"created_by"?: string | null,"expires_at"?: string,"max_uses"?: number,"revoked_at"?: string | null,"uses"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "company_invites_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "company_invites_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"device_tokens": {
                  Row: {
                    "platform": string,"token": string,"updated_at": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "platform": string,"token": string,"updated_at"?: string,"user_id": string
                  }
                  Update: {
                    "platform"?: string,"token"?: string,"updated_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "device_tokens_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"job_requirements": {
                  Row: {
                    "evidence": string | null,"id": string,"job_id": string,"min_years": number,"required": boolean,"skill_id": string,"weight": number
                  }
                  ComputedFields: never
                  Insert: {
                    "evidence"?: string | null,"id"?: string,"job_id": string,"min_years"?: number,"required"?: boolean,"skill_id": string,"weight"?: number
                  }
                  Update: {
                    "evidence"?: string | null,"id"?: string,"job_id"?: string,"min_years"?: number,"required"?: boolean,"skill_id"?: string,"weight"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_requirements_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "company_jobs_overview"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_requirements_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_requirements_skill_id_fkey"
      columns: ["skill_id"]
isOneToOne: false
      referencedRelation: "skills"
      referencedColumns: ["id"]
    }
                  ]
                },"jobs": {
                  Row: {
                    "company_id": string,"created_at": string,"created_by": string | null,"embedding": string | null,"embedding_model": string | null,"expires_at": string | null,"id": string,"is_seed": boolean,"job_type": Database["public"]['Enums']["job_type"] | null,"location": string | null,"parse_status": Database["public"]['Enums']["parse_status"],"published_at": string | null,"raw_description": string,"remote": Database["public"]['Enums']["remote_type"] | null,"rescored_at": string | null,"salary_max": number | null,"salary_min": number | null,"sponsorship": boolean,"status": Database["public"]['Enums']["job_status"],"title": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "company_id": string,"created_at"?: string,"created_by"?: string | null,"embedding"?: string | null,"embedding_model"?: string | null,"expires_at"?: string | null,"id"?: string,"is_seed"?: boolean,"job_type"?: Database["public"]['Enums']["job_type"] | null,"location"?: string | null,"parse_status"?: Database["public"]['Enums']["parse_status"],"published_at"?: string | null,"raw_description": string,"remote"?: Database["public"]['Enums']["remote_type"] | null,"rescored_at"?: string | null,"salary_max"?: number | null,"salary_min"?: number | null,"sponsorship"?: boolean,"status"?: Database["public"]['Enums']["job_status"],"title"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "company_id"?: string,"created_at"?: string,"created_by"?: string | null,"embedding"?: string | null,"embedding_model"?: string | null,"expires_at"?: string | null,"id"?: string,"is_seed"?: boolean,"job_type"?: Database["public"]['Enums']["job_type"] | null,"location"?: string | null,"parse_status"?: Database["public"]['Enums']["parse_status"],"published_at"?: string | null,"raw_description"?: string,"remote"?: Database["public"]['Enums']["remote_type"] | null,"rescored_at"?: string | null,"salary_max"?: number | null,"salary_min"?: number | null,"sponsorship"?: boolean,"status"?: Database["public"]['Enums']["job_status"],"title"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "jobs_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jobs_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"llm_usage": {
                  Row: {
                    "created_at": string,"function_name": string,"id": number,"input_tokens": number,"latency_ms": number | null,"model": string,"output_tokens": number,"provider": string,"user_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"function_name": string,"id"?: never,"input_tokens"?: number,"latency_ms"?: number | null,"model": string,"output_tokens"?: number,"provider": string,"user_id"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"function_name"?: string,"id"?: never,"input_tokens"?: number,"latency_ms"?: number | null,"model"?: string,"output_tokens"?: number,"provider"?: string,"user_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "llm_usage_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"profile_versions": {
                  Row: {
                    "candidate_id": string,"confirmed": boolean,"confirmed_at": string | null,"created_at": string,"education": NonNullable<Json>,"embedding": string | null,"embedding_model": string | null,"id": string,"is_seed": boolean,"llm_model": string | null,"resume_id": string | null,"schema_version": number | null,"source": Database["public"]['Enums']["profile_source"],"total_years": number | null,"version": number
                  }
                  ComputedFields: never
                  Insert: {
                    "candidate_id": string,"confirmed"?: boolean,"confirmed_at"?: string | null,"created_at"?: string,"education"?: NonNullable<Json>,"embedding"?: string | null,"embedding_model"?: string | null,"id"?: string,"is_seed"?: boolean,"llm_model"?: string | null,"resume_id"?: string | null,"schema_version"?: number | null,"source"?: Database["public"]['Enums']["profile_source"],"total_years"?: number | null,"version": number
                  }
                  Update: {
                    "candidate_id"?: string,"confirmed"?: boolean,"confirmed_at"?: string | null,"created_at"?: string,"education"?: NonNullable<Json>,"embedding"?: string | null,"embedding_model"?: string | null,"id"?: string,"is_seed"?: boolean,"llm_model"?: string | null,"resume_id"?: string | null,"schema_version"?: number | null,"source"?: Database["public"]['Enums']["profile_source"],"total_years"?: number | null,"version"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "profile_versions_candidate_id_fkey"
      columns: ["candidate_id"]
isOneToOne: false
      referencedRelation: "candidates"
      referencedColumns: ["profile_id"]
    },{
      foreignKeyName: "profile_versions_resume_id_fkey"
      columns: ["resume_id"]
isOneToOne: false
      referencedRelation: "resumes"
      referencedColumns: ["id"]
    }
                  ]
                },"profiles": {
                  Row: {
                    "created_at": string,"display_name": string | null,"id": string,"is_seed": boolean,"role": Database["public"]['Enums']["app_role"] | null,"terms_accepted_at": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"display_name"?: string | null,"id": string,"is_seed"?: boolean,"role"?: Database["public"]['Enums']["app_role"] | null,"terms_accepted_at"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"display_name"?: string | null,"id"?: string,"is_seed"?: boolean,"role"?: Database["public"]['Enums']["app_role"] | null,"terms_accepted_at"?: string | null,"updated_at"?: string
                  }
                  Relationships: [

                  ]
                },"recruiters": {
                  Row: {
                    "company_id": string,"company_role": Database["public"]['Enums']["company_role"],"created_at": string,"profile_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "company_id": string,"company_role"?: Database["public"]['Enums']["company_role"],"created_at"?: string,"profile_id": string
                  }
                  Update: {
                    "company_id"?: string,"company_role"?: Database["public"]['Enums']["company_role"],"created_at"?: string,"profile_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "recruiters_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recruiters_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"resumes": {
                  Row: {
                    "candidate_id": string,"created_at": string,"extraction": Json | null,"failure_reason": string | null,"file_hash": string,"id": string,"is_seed": boolean,"llm_model": string | null,"llm_provider": string | null,"mime_type": string,"schema_version": number | null,"status": Database["public"]['Enums']["resume_status"],"storage_path": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "candidate_id": string,"created_at"?: string,"extraction"?: Json | null,"failure_reason"?: string | null,"file_hash": string,"id"?: string,"is_seed"?: boolean,"llm_model"?: string | null,"llm_provider"?: string | null,"mime_type": string,"schema_version"?: number | null,"status"?: Database["public"]['Enums']["resume_status"],"storage_path": string,"updated_at"?: string
                  }
                  Update: {
                    "candidate_id"?: string,"created_at"?: string,"extraction"?: Json | null,"failure_reason"?: string | null,"file_hash"?: string,"id"?: string,"is_seed"?: boolean,"llm_model"?: string | null,"llm_provider"?: string | null,"mime_type"?: string,"schema_version"?: number | null,"status"?: Database["public"]['Enums']["resume_status"],"storage_path"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "resumes_candidate_id_fkey"
      columns: ["candidate_id"]
isOneToOne: false
      referencedRelation: "candidates"
      referencedColumns: ["profile_id"]
    }
                  ]
                },"skill_relations": {
                  Row: {
                    "credit": number,"related_skill_id": string,"skill_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "credit": number,"related_skill_id": string,"skill_id": string
                  }
                  Update: {
                    "credit"?: number,"related_skill_id"?: string,"skill_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "skill_relations_related_skill_id_fkey"
      columns: ["related_skill_id"]
isOneToOne: false
      referencedRelation: "skills"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "skill_relations_skill_id_fkey"
      columns: ["skill_id"]
isOneToOne: false
      referencedRelation: "skills"
      referencedColumns: ["id"]
    }
                  ]
                },"skills": {
                  Row: {
                    "aliases": (string)[],"category": string,"embedding": string | null,"embedding_model": string | null,"id": string,"is_seed": boolean,"name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "aliases"?: (string)[],"category": string,"embedding"?: string | null,"embedding_model"?: string | null,"id"?: string,"is_seed"?: boolean,"name": string
                  }
                  Update: {
                    "aliases"?: (string)[],"category"?: string,"embedding"?: string | null,"embedding_model"?: string | null,"id"?: string,"is_seed"?: boolean,"name"?: string
                  }
                  Relationships: [

                  ]
                },"status_events": {
                  Row: {
                    "actor_id": string | null,"application_id": string,"created_at": string,"from_status": Database["public"]['Enums']["application_status"] | null,"id": number,"to_status": Database["public"]['Enums']["application_status"]
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"application_id": string,"created_at"?: string,"from_status"?: Database["public"]['Enums']["application_status"] | null,"id"?: never,"to_status": Database["public"]['Enums']["application_status"]
                  }
                  Update: {
                    "actor_id"?: string | null,"application_id"?: string,"created_at"?: string,"from_status"?: Database["public"]['Enums']["application_status"] | null,"id"?: never,"to_status"?: Database["public"]['Enums']["application_status"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "status_events_actor_id_fkey"
      columns: ["actor_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "status_events_application_id_fkey"
      columns: ["application_id"]
isOneToOne: false
      referencedRelation: "applications"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "status_events_application_id_fkey"
      columns: ["application_id"]
isOneToOne: false
      referencedRelation: "my_applications"
      referencedColumns: ["id"]
    }
                  ]
                },"swipes": {
                  Row: {
                    "candidate_id": string,"created_at": string,"direction": Database["public"]['Enums']["swipe_direction"],"id": string,"is_seed": boolean,"job_id": string,"pass_reason": Database["public"]['Enums']["pass_reason"] | null
                  }
                  ComputedFields: never
                  Insert: {
                    "candidate_id": string,"created_at"?: string,"direction": Database["public"]['Enums']["swipe_direction"],"id"?: string,"is_seed"?: boolean,"job_id": string,"pass_reason"?: Database["public"]['Enums']["pass_reason"] | null
                  }
                  Update: {
                    "candidate_id"?: string,"created_at"?: string,"direction"?: Database["public"]['Enums']["swipe_direction"],"id"?: string,"is_seed"?: boolean,"job_id"?: string,"pass_reason"?: Database["public"]['Enums']["pass_reason"] | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "swipes_candidate_id_fkey"
      columns: ["candidate_id"]
isOneToOne: false
      referencedRelation: "candidates"
      referencedColumns: ["profile_id"]
    },{
      foreignKeyName: "swipes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "company_jobs_overview"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "swipes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            "company_jobs_overview": {
                  Row: {
                    "company_id": string | null,"expires_at": string | null,"id": string | null,"new_count": number | null,"published_at": string | null,"status": Database["public"]['Enums']["job_status"] | null,"title": string | null,"total_count": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "jobs_company_id_fkey"
      columns: ["company_id"]
isOneToOne: false
      referencedRelation: "companies"
      referencedColumns: ["id"]
    }
                  ]
                },"my_applications": {
                  Row: {
                    "breakdown": Json | null,"committed_at": string | null,"company_name": string | null,"company_verified": boolean | null,"created_at": string | null,"id": string | null,"interview_note": string | null,"job_id": string | null,"job_title": string | null,"match_score": number | null,"status": Database["public"]['Enums']["application_status"] | null,"updated_at": string | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "applications_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "company_jobs_overview"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "applications_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Functions: {
            "advance":
{ Args: { "p_application_id": string,"p_note"?: string }; Returns: undefined
                           },
"advance_resume_status":
{ Args: { "p_from": Database["public"]['Enums']["resume_status"],"p_resume_id": string,"p_to": Database["public"]['Enums']["resume_status"] }; Returns: boolean
                           },
"application_tile":
{ Args: { "p_row": Omit<Database["public"]['Tables']["applications"]['Row'], Database["public"]['Tables']["applications"]['ComputedFields']> }; Returns: Json
                           },
"blind_evidence":
{ Args: { "p_candidate": string,"p_text": string }; Returns: string
                           },
"candidate_upload_allowed":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"change_application":
{ Args: { "p_action": string,"p_id": string,"p_text"?: string }; Returns: undefined
                           },
"claim_resume_parse":
{ Args: { "p_resume_id": string,"p_stale_seconds"?: number }; Returns: boolean
                           },
"company_domain_verified":
{ Args: { "p_owner": string,"p_website": string }; Returns: boolean
                           },
"compute_match":
{ Args: { "p_job_id": string,"p_profile_version_id": string }; Returns: Json
                           },
"confirm_profile":
{ Args: { "p_skills": Json,"p_version_id": string }; Returns: undefined
                           },
"create_company":
{ Args: { "p_name": string,"p_website"?: string }; Returns: {
              "created_at": string,
"created_by": string | null,
"id": string,
"is_seed": boolean,
"logo_path": string | null,
"name": string,
"updated_at": string,
"verified": boolean,
"website": string | null
            }
                          SetofOptions: {
        from: "*"
        to: "companies"
        isOneToOne: true
        isSetofReturn: false
      } },
"create_invite":
{ Args: { "p_expires_in_days"?: number }; Returns: string
                           },
"create_manual_profile":
{ Args: Record<PropertyKey, never>; Returns: {
              "candidate_id": string,
"confirmed": boolean,
"confirmed_at": string | null,
"created_at": string,
"education": NonNullable<Json>,
"embedding": string | null,
"embedding_model": string | null,
"id": string,
"is_seed": boolean,
"llm_model": string | null,
"resume_id": string | null,
"schema_version": number | null,
"source": Database["public"]['Enums']["profile_source"],
"total_years": number | null,
"version": number
            }
                          SetofOptions: {
        from: "*"
        to: "profile_versions"
        isOneToOne: true
        isSetofReturn: false
      } },
"create_review_draft":
{ Args: Record<PropertyKey, never>; Returns: {
              "candidate_id": string,
"confirmed": boolean,
"confirmed_at": string | null,
"created_at": string,
"education": NonNullable<Json>,
"embedding": string | null,
"embedding_model": string | null,
"id": string,
"is_seed": boolean,
"llm_model": string | null,
"resume_id": string | null,
"schema_version": number | null,
"source": Database["public"]['Enums']["profile_source"],
"total_years": number | null,
"version": number
            }
                          SetofOptions: {
        from: "*"
        to: "profile_versions"
        isOneToOne: true
        isSetofReturn: false
      } },
"current_app_role":
{ Args: Record<PropertyKey, never>; Returns: Database["public"]['Enums']["app_role"]
                           },
"fail_job_parse":
{ Args: { "p_job_id": string }; Returns: boolean
                           },
"fail_resume_parse":
{ Args: { "p_reason": string,"p_resume_id": string }; Returns: boolean
                           },
"feed_affinity":
{ Args: { "p_candidate_id": string,"p_company_id": string,"p_match_score": number,"p_remote": Database["public"]['Enums']["remote_type"],"p_salary_max": number }; Returns: number
                           },
"feed_exploration":
{ Args: { "p_job_id": string }; Returns: number
                           },
"feed_freshness":
{ Args: { "p_published_at": string }; Returns: number
                           },
"get_application_contact":
{ Args: { "p_application_id": string }; Returns: Json
                           },
"get_board":
{ Args: { "p_filters"?: Json,"p_job_id": string,"p_limit"?: number,"p_offset"?: number }; Returns: Json
                           },
"get_candidate_detail":
{ Args: { "p_application_id": string }; Returns: Json
                           },
"get_feed":
{ Args: { "p_cursor"?: string,"p_limit"?: number }; Returns: Json
                           },
"get_interview_list":
{ Args: { "p_job_id"?: string }; Returns: Json
                           },
"get_resume_access":
{ Args: { "p_application_id": string }; Returns: string
                           },
"has_my_application":
{ Args: { "p_job_id": string }; Returns: boolean
                           },
"join_company":
{ Args: { "p_code": string }; Returns: {
              "created_at": string,
"created_by": string | null,
"id": string,
"is_seed": boolean,
"logo_path": string | null,
"name": string,
"updated_at": string,
"verified": boolean,
"website": string | null
            }
                          SetofOptions: {
        from: "*"
        to: "companies"
        isOneToOne: true
        isSetofReturn: false
      } },
"match_band":
{ Args: { "p_score": number }; Returns: string
                           },
"match_skills":
{ Args: { "p_embedding": string,"p_k"?: number,"p_threshold"?: number }; Returns: {
              "name": string,"similarity": number,"skill_id": string
            }[]
                           },
"my_company_id":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"my_owned_company_id":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"open_application":
{ Args: { "p_application_id": string }; Returns: undefined
                           },
"prepare_account_deletion":
{ Args: Record<PropertyKey, never>; Returns: undefined
                           },
"reject":
{ Args: { "p_application_id": string,"p_reason"?: string }; Returns: undefined
                           },
"revoke_invite":
{ Args: { "p_code": string }; Returns: undefined
                           },
"save_job_draft":
{ Args: { "p_fields": Json,"p_job_id": string,"p_requirements": Json }; Returns: Json
                           },
"save_parsed_profile":
{ Args: { "p_candidate_id": string,"p_education": Json,"p_experiences": Json,"p_llm_model": string,"p_schema_version": number,"p_skills": Json,"p_total_years": number }; Returns: {
              "profile_version_id": string,"version": number
            }[]
                           },
"save_preferences":
{ Args: { "p_prefs": Json }; Returns: undefined
                           },
"save_requirements":
{ Args: { "p_job_id": string,"p_requirements": Json }; Returns: undefined
                           },
"save_resume_draft":
{ Args: { "p_education": Json,"p_extraction": Json,"p_file_hash": string,"p_llm_model": string,"p_llm_provider": string,"p_resume_id": string,"p_schema_version": number,"p_skills": Json,"p_total_years": number }; Returns: {
              "profile_version_id": string,"version": number
            }[]
                           },
"set_initial_role":
{ Args: { "p_role": Database["public"]['Enums']["app_role"] }; Returns: undefined
                           },
"set_job_status":
{ Args: { "p_job_id": string,"p_status": Database["public"]['Enums']["job_status"] }; Returns: undefined
                           },
"set_pass_reason":
{ Args: { "p_reason": Database["public"]['Enums']["pass_reason"],"p_swipe_id": string }; Returns: undefined
                           },
"skills_centroid":
{ Args: { "p_skill_ids": (string)[] }; Returns: string
                           },
"start_job_parse":
{ Args: { "p_job_id": string }; Returns: boolean
                           },
"swipe":
{ Args: { "p_direction": Database["public"]['Enums']["swipe_direction"],"p_job_id": string,"p_reason"?: Database["public"]['Enums']["pass_reason"] }; Returns: Json
                           },
"undo_reject":
{ Args: { "p_application_id": string }; Returns: undefined
                           },
"undo_swipe":
{ Args: { "p_swipe_id": string }; Returns: undefined
                           },
"withdraw":
{ Args: { "p_application_id": string }; Returns: undefined
                           }
          }
          Enums: {
            "app_role": "candidate"|"recruiter","application_status": "APPLIED"|"UNDER_REVIEW"|"INTERVIEW_REQUESTED"|"NOT_SELECTED"|"WITHDRAWN"|"JOB_CLOSED","company_role": "owner"|"member","experience_kind": "job"|"internship"|"research"|"project"|"volunteer"|"other","job_status": "DRAFT"|"OPEN"|"PAUSED"|"CLOSED","job_type": "full_time"|"part_time"|"contract"|"internship","parse_status": "PENDING"|"READY"|"FAILED","pass_reason": "location"|"salary"|"stack"|"seniority"|"company","profile_source": "resume"|"manual","remote_type": "onsite"|"hybrid"|"remote","resume_status": "UPLOADED"|"PARSING_LAYOUT"|"EXTRACTING"|"NORMALIZING"|"READY"|"FAILED","skill_source": "ai"|"user","swipe_direction": "left"|"right"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {

          }
        },"public": {
          Enums: {
            "app_role": ["candidate", "recruiter"],"application_status": ["APPLIED", "UNDER_REVIEW", "INTERVIEW_REQUESTED", "NOT_SELECTED", "WITHDRAWN", "JOB_CLOSED"],"company_role": ["owner", "member"],"experience_kind": ["job", "internship", "research", "project", "volunteer", "other"],"job_status": ["DRAFT", "OPEN", "PAUSED", "CLOSED"],"job_type": ["full_time", "part_time", "contract", "internship"],"parse_status": ["PENDING", "READY", "FAILED"],"pass_reason": ["location", "salary", "stack", "seniority", "company"],"profile_source": ["resume", "manual"],"remote_type": ["onsite", "hybrid", "remote"],"resume_status": ["UPLOADED", "PARSING_LAYOUT", "EXTRACTING", "NORMALIZING", "READY", "FAILED"],"skill_source": ["ai", "user"],"swipe_direction": ["left", "right"]
          }
        }
} as const
