pipeline {
    agent any
    environment {
        GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-service-account-key')
    }
    stages {
        stage('Terraform Init') {
            steps {
                sh 'terraform init -reconfigure'
            }
        }
        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }
        stage('Approval') {
            steps {
                input message: 'Lanjutkan ke Apply?', ok: 'Proceed'
            }
        }
        stage('Terraform Apply') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }
    
    // Blok ini akan mengirim Email Notifikasi otomatis
    post {
        success {
            script {
                mail to: 'GANTI_DENGAN_EMAIL_KAMU@gmail.com', // <--- UBAH INI
                     subject: "SUCCESS: Jenkins Pipeline ${currentBuild.fullDisplayName}",
                     body: "Halo,\n\nPipeline untuk infrastruktur Terraform telah berhasil dieksekusi dengan aman.\n\nCek log lengkapnya di sini: ${env.BUILD_URL}"
            }
        }
        failure {
            script {
                mail to: 'GANTI_DENGAN_EMAIL_KAMU@gmail.com', // <--- UBAH INI
                     subject: "FAILED: Jenkins Pipeline ${currentBuild.fullDisplayName}",
                     body: "Peringatan!\n\nPipeline infrastruktur GAGAL dieksekusi. Segera periksa log error di Jenkins untuk investigasi lebih lanjut:\n\n${env.BUILD_URL}"
            }
        }
    }
}
