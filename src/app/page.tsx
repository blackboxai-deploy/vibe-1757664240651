"use client"

import { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useForm } from 'react-hook-form'
import { z } from 'zod'


const formSchema = z.object({
  action: z.string().min(1, 'Action is required'),
  data: z.string().min(1, 'Data is required'),
  user: z.string().min(1, 'User is required').email('Invalid email'),
})

export default function Dashboard() {
  const [analytics, setAnalytics] = useState(null)
  const [loading, setLoading] = useState(true)
  const [submitStatus, setSubmitStatus] = useState(null)
  const form = useForm<z.infer<typeof formSchema>>({
    defaultValues: {
      action: '',
      data: '',
      user: 'louiewong4@gmail.com',
    },
  })

  useEffect(() => {
    fetchAnalytics()
  }, [])

  const fetchAnalytics = async () => {
    setLoading(true) 
    try {
      const res = await fetch('/api/analytics?timeframe=24h')
      const data = await res.json()
      setAnalytics(data.data)
    } catch (error) {
      console.error('Failed to fetch analytics', error)
    }
    setLoading(false)
  }

  const onSubmit = async (values: z.infer<typeof formSchema>) {
    try {
      const res = await fetch('/api/collaborative', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(values),
      })
      const data = await res.json()
      setSubmitStatus(data.success ? 'Event logged successfully' : 'Failed to log event')
    } catch (error) {
      setSubmitStatus('Error submitting event')
    }
  }

  return (
    <div className="container mx-auto p-4 max-w-6xl">
      <h1 className="text-3xl font-bold mb-6 text-center">Gaia-X Temporary Command Center</h1>
      <Tabs defaultValue="analytics" className="space-y-4">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="analytics">Analytics</TabsTrigger>
          <TabsTrigger value="collaborative">Collaborative Events</TabsTrigger>
        </TabsList>
        <TabsContent value="analytics" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>System Analytics (Last 24h)</CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <p>Loading analytics...</p>
              ) : analytics ? (
                <div className="space-y-6">
                  <div>
                    <h3 className="font-semibold mb-2">Voice Commands</h3>
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>Total</TableHead>
                          <TableHead>Successful</TableHead>
                          <TableHead>Failed</TableHead>
                          <TableHead>Success Rate</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        <TableRow>
                          <TableCell>{analytics.voice_commands.total}</TableCell>
                          <TableCell>{analytics.voice_commands.successful}</TableCell>
                          <TableCell>{analytics.voice_commands.failed}</TableCell>
                          <TableCell>{analytics.voice_commands.success_rate}</TableCell>
                        </TableRow>
                      </TableBody>
                    </Table>
                  </div>
                  {/* Similar sections for other analytics data */}
                  <div>
                    <h3 className="font-semibold mb-2">Worker Deployments</h3>
                    <p>Total: {analytics.worker_deployments.total} | Active: {analytics.worker_deployments.active} | Failed: {analytics.worker_deployments.failed}</p>
                    <p>Regions: {analytics.worker_deployments.regions.join(', ')}</p>
                  </div>
                  {/* Add more cards/tables for other sections as needed */}
                </div>
              ) : (
                <p>No analytics data available</p>
              )}
              <Button onClick={fetchAnalytics} className="mt-4">Refresh Analytics</Button>
            </CardContent>
          </Card>
        </TabsContent>
        <TabsContent value="collaborative" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Log Collaborative Event</CardTitle>
            </CardHeader>
            <CardContent>
              <Form {...form}>
                <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                  <FormField
                    control={form.control}
                    name="action"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Action</FormLabel>
                        <FormControl>
                          <Input placeholder="e.g., deploy_worker" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="data"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Data</FormLabel>
                        <FormControl>
                          <Input placeholder="e.g., {'region': 'US-East'}" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="user"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>User Email</FormLabel>
                        <FormControl>
                          <Input placeholder="louiewong4@gmail.com" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <Button type="submit">Log Event</Button>
                </form>
              </Form>
              {submitStatus && <p className="mt-4">{submitStatus}</p>}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}